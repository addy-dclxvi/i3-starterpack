import asyncio
from collections import Counter
import concurrent.futures
import difflib
import fnmatch
import functools
import glob
import heapq
import importlib
from importlib.util import find_spec
import io
import itertools
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
from tempfile import TemporaryFile
import threading
import time

if find_spec('pynvim'):
    import pynvim as neovim
else:
    import neovim

@neovim.plugin
class Wilder(object):
    def __init__(self, nvim):
        self.nvim = nvim
        self.has_init = False
        self.events = []
        self.events_lock = threading.Lock()
        self.executor = None
        self.cached_buffer = {'bufnr': -1, 'undotree_seq_cur': -1, 'buffer': []}
        self.run_id = -1
        self.find_files_lock = threading.Lock()
        self.find_files_timestamp = -1
        self.find_files_cache = dict()
        self.help_tags_lock = threading.Lock()
        self.help_tags_session_id = -1
        self.help_tags_result = None
        self.added_sys_path = set()

    def resolve(self, ctx, x):
        self.nvim.async_call(self._resolve, ctx, x)

    def _resolve(self, ctx, x):
        self.nvim.call('wilder#resolve', ctx, x)

    def reject(self, ctx, x):
        self.nvim.async_call(self._reject, ctx, x)

    def _reject(self, ctx, x):
        self.nvim.call('wilder#reject', ctx, x)

    def echomsg(self, x):
        self.nvim.session.threadsafe_call(lambda: self.nvim.command('echomsg "' + x + '"'))

    def run_in_background(self, fn, args):
        event = threading.Event()
        ctx = args[0]

        old_events = []
        with self.events_lock:
            run_id = ctx['run_id']
            if run_id < self.run_id:
                return

            if run_id > self.run_id:
                self.run_id = run_id
                old_events = self.events
                self.events = []

            self.events.append(event)

        for ev in old_events:
            ev.set()

        return self.executor.submit(functools.partial( fn, *([event] + args), ))

    @neovim.function('_wilder_init', sync=True)
    def _init(self, args):
        if self.has_init:
            return

        self.has_init = True

        opts = args[0]

        self.executor = concurrent.futures.ThreadPoolExecutor(max_workers=opts['num_workers'])

    def add_sys_path(self, path):
        path = os.path.expanduser(path)

        if not path in self.added_sys_path:
            self.added_sys_path.add(path)
            sys.path.insert(0, path)

    @neovim.function('_wilder_python_file_finder', sync=False, allow_nested=True)
    def _file_finder(self, args):
        self.run_in_background(self.file_finder_handler, args)

    def file_finder_handler(self, event, ctx, opts, command, filters, cwd, path, query, find_dir, timestamp):
        try:
            if not path:
                path = cwd

            path = Path(os.path.expanduser(path)).resolve()
            path_str = str(path)
            key = str(path) + ':' + str(command)

            result = None
            with self.find_files_lock:
                if timestamp > self.find_files_timestamp:
                    self.find_files_timestamp = timestamp

                    for result in self.find_files_cache.values():
                        result['kill'].set()

                    self.find_files_cache = dict()

                if key in self.find_files_cache:
                    result = self.find_files_cache[key]
                else:
                    timeout_ms = opts['timeout'] if 'timeout' in opts else 5000

                    kill_event = threading.Event()
                    done_event = threading.Event()
                    result = {'kill': kill_event, 'done': done_event}
                    self.find_files_cache[key] = result
                    self.executor.submit(functools.partial( self.find_files_subprocess, *([command, path, timeout_ms, result]), ))

            while True:
                if result['done'].is_set():
                    break
                if event.wait(timeout=0.01):
                    return

            if 'timeout' in result:
                self.resolve(ctx, False)
                return

            if 'error' in result:
                self.reject(ctx, 'python_file_finder: %s %s' % (command, result['error']))
                return

            candidates = result['files']

            if not candidates:
                return self.resolve(ctx, [])

            if query:
                for filter in filters:
                    filter_name = filter['name']
                    filter_opts = filter['opts']

                    if filter_name == 'cpsm_filter':
                        filter_opts['ispath'] = True
                        candidates = self.cpsm_filt(event, filter_opts, candidates, query)

                    elif filter_name == 'clap_filter':
                        candidates = self.clap_filt(event, filter_opts, candidates, query)

                    elif filter_name == 'fruzzy_filter':
                        candidates = self.fruzzy_filt(event, filter_opts, candidates, query)

                    elif filter_name == 'fuzzy_filter':
                        case_sensitive = filter_opts['case_sensitive'] if 'case_sensitive' in filter_opts else 2
                        pattern = self.make_fuzzy_pattern(query, case_sensitive)
                        candidates = self.fuzzy_filt(event, filter_opts, candidates, pattern)

                    elif filter_name == 'difflib_sorter':
                        candidates = self.difflib_sort(event, filter_opts, candidates, query)

                    elif filter_name == 'fuzzywuzzy_sorter':
                        candidates = self.fuzzywuzzy_sort(event, filter_opts, candidates, query)

                    else:
                        raise Exception('Unsupported filter: ' + filter_name)

                    if candidates is None or event.is_set():
                        return
                    candidates = list(candidates)

            if event.is_set():
                return

            relative_to_cwd = opts['relative_to_cwd'] if 'relative_to_cwd' in opts else True

            if relative_to_cwd:
                relpath = os.path.relpath(path, cwd)
                if relpath != '.':
                    candidates = [os.path.join(relpath, c) for c in candidates]

            if find_dir:
                candidates = [c + os.sep if c and c[-1] != os.sep else c  for c in candidates]

            self.resolve(ctx, candidates)
        except Exception as e:
            self.reject(ctx, 'python_file_finder: ' + str(e))

    def find_files_subprocess(self, command, path, timeout_ms, result):
        try:
            with TemporaryFile() as output:
                with subprocess.Popen(
                        command, bufsize=0, stdin=subprocess.DEVNULL,
                        stdout=output, stderr=subprocess.PIPE, cwd=path) as p:
                    start_time = time.time()
                    while p.poll() is None:
                        if time.time() - start_time >= timeout_ms / 1000:
                            result['timeout'] = 'timeout after %dms' % (timeout_ms)
                            p.kill()
                            break
                        if result['kill'].wait(timeout=0.01):
                            p.kill()
                            break

                    if p.returncode is not 0:
                        has_error = False

                        # rg sets error code 2 for partial matches (e.g. some files can't be read), which we are fine with
                        if command[0] != 'rg' or p.returncode is not 2:
                            has_error = True
                        else:
                            output.seek(0)
                            # check if return code 2 is due to partial match by checking if stdout is populated
                            # if stdout is empty, treat it as an error
                            if not output.read(1):
                                has_error = True

                        if has_error:
                            pattern = re.compile(r'(\x9B|\x1B\[)[0-?]*[ -\/]*[@-~]')
                            error = p.stderr.read().decode('utf-8')
                            error = pattern.sub('', error)
                            result['error'] = 'return code %d:\n%s' % (p.returncode, error)
                            return

                    output.seek(0)
                    buff = output.read()
                    result['files'] = [line.decode('utf-8') for line in buff.splitlines()]
        except Exception as e:
            result['error'] = repr(e)
        finally:
            result['done'].set()

    @neovim.function('_wilder_python_sleep', sync=False, allow_nested=True)
    def _sleep(self, args):
        self.run_in_background(self.sleep_handler, args)

    def sleep_handler(self, event, ctx, t, x):
        if event.is_set():
            return

        time.sleep(t)
        self.resolve(ctx, x)

    @neovim.function('_wilder_python_search', sync=False, allow_nested=True)
    def _search(self, args):
        bufnr = self.nvim.current.buffer.number
        undotree_seq_cur = self.nvim.eval('undotree().seq_cur')
        if (bufnr != self.cached_buffer['bufnr'] or
                undotree_seq_cur != self.cached_buffer['undotree_seq_cur']):
            self.cached_buffer = {
                'bufnr': bufnr,
                'undotree_seq_cur': undotree_seq_cur,
                'buffer': list(self.nvim.current.buffer),
                }

        self.run_in_background(self.search_handler, args + [self.cached_buffer['buffer']])

    def search_handler(self, event, ctx, *args):
        try:
            candidates = list(self.search(event, *args))

            if event.is_set():
                return

            self.resolve(ctx, candidates)
        except Exception as e:
            self.reject(ctx, 'python_search: ' + str(e))

    def search(self, event, opts, x, buf):
        module_name = opts['engine'] if 'engine' in opts else 're'
        max_candidates = opts['max_candidates'] if 'max_candidates' in opts else 300

        re = importlib.import_module(module_name)
        # re2 does not use re.UNICODE by default
        pattern = re.compile(x, re.UNICODE)

        seen = set()
        checker = EventChecker(event)
        for line in buf:
            for match in pattern.finditer(line):
                if checker.check():
                    return

                candidate = match.group()
                if not candidate in seen:
                    seen.add(candidate)
                    yield candidate

                    if max_candidates > 0 and len(seen) >= max_candidates:
                        return

    @neovim.function('_wilder_python_uniq_filt', sync=False, allow_nested=True)
    def _uniq_filt(self, args):
        self.run_in_background(self.uniq_filt_handler, args)

    def uniq_filt_handler(self, event, ctx, candidates):
        if event.is_set():
            return

        seen = set()

        try:
            res = [x for x in candidates if not (x in seen or seen.add(x))]
            self.resolve(ctx, res)
        except Exception as e:
            self.reject(ctx, 'python_uniq_filt: ' + str(e))

    @neovim.function('_wilder_python_lexical_sort', sync=False, allow_nested=True)
    def _sort(self, args):
        self.run_in_background(self.lexical_sort_handler, args)

    def lexical_sort_handler(self, event, ctx, candidates):
        if event.is_set():
            return

        try:
            res = sorted(candidates)

            self.resolve(ctx, res)
        except Exception as e:
            self.reject(ctx, 'python_lexical_sort: ' + str(e))

    # sync=True as it needs to query nvim for some data
    @neovim.function('_wilder_python_get_file_completion', sync=True, allow_nested=True)
    def _get_file_completion(self, args):
        expand_arg = args[1]
        expand_type = args[2]

        cwd = self.nvim.eval('getcwd()')
        wildignore_opt = self.nvim.eval('&wildignore')
        current_file_dir = self.nvim.eval('expand("%:p:h")')

        add_dot = False

        if expand_type == 'file_in_path':
            path_opt = self.nvim.eval('&path')
            directories = path_opt.split(',')
        elif expand_type == 'shellcmd':
            directories = []
            if expand_arg:
                if expand_arg[0:2] == './':
                    directories = [cwd]
                else:
                    relpath = os.path.relpath(expand_arg, cwd)
                    if relpath[0:2] == '..':
                        add_dot = True
                        directories = [cwd]

            if not directories:
                path = os.environ['PATH']
                directories = path.split(':')
                directories += [cwd]
        else:
            directories = [cwd]

        self.run_in_background(self.get_file_completion_handler, args + [wildignore_opt, directories, add_dot, cwd, current_file_dir])

    def get_file_completion_handler(self,
                                    event,
                                    ctx,
                                    expand_arg,
                                    expand_type,
                                    has_wildcard,
                                    path_prefix,
                                    wildignore_opt,
                                    directories,
                                    add_dot,
                                    cwd,
                                    current_file_dir):
        if event.is_set():
            return

        try:
            original_has_wildcard = has_wildcard
            res = list()
            seen_files = set()
            wildignore_list = wildignore_opt.split(',')
            is_file_in_path = expand_type == 'file_in_path'
            visited_directories = set()

            checker = EventChecker(event)
            for directory in directories:
                if checker.check():
                    return

                if is_file_in_path:
                    if not directory:
                        directory = cwd
                    elif directory == '.':
                        directory = current_file_dir

                if not directory:
                    continue

                if directory in visited_directories:
                    continue

                visited_directories.add(directory)

                has_wildcard = original_has_wildcard or '*' in directory
                if has_wildcard:
                    tail = os.path.basename(expand_arg)
                    show_hidden = tail.startswith('.')
                    pattern = ''
                    if is_file_in_path:
                        if directory == '**':
                            wildcard = os.path.join(cwd, '**')
                        else:
                            wildcard = directory
                    elif expand_arg:
                        wildcard = os.path.join(directory, expand_arg)
                    else:
                        wildcard = directory
                    wildcard = os.path.expandvars(wildcard)

                    it = glob.iglob(wildcard, recursive=True)
                else:
                    if add_dot:
                        path = os.path.join('.', directory, expand_arg)
                    else:
                        path = os.path.join(directory, expand_arg)
                    head, tail = os.path.split(path)
                    show_hidden = tail.startswith('.')
                    if is_file_in_path:
                        pattern = ''
                    else:
                        pattern = tail + '*'

                    try:
                        it = os.scandir(head)
                    except FileNotFoundError:
                        continue
                    except NotADirectoryError:
                        continue

                for entry in it:
                    if checker.check():
                        return
                    try:
                        if has_wildcard:
                            entry = Path(entry)
                            try:
                                entry = entry.relative_to(directory)
                                old_entry = Path(entry)
                            except ValueError:
                                pass
                        if entry.name.startswith('.') and not show_hidden:
                            continue
                        if expand_type == 'dir' and not entry.is_dir():
                            continue
                        ignore = False
                        for wildignore in wildignore_list:
                            if fnmatch.fnmatch(entry.name, wildignore):
                                ignore = True
                                break
                        if ignore:
                            continue
                        if not has_wildcard and pattern and not fnmatch.fnmatch(entry.name, pattern):
                            continue
                        if expand_type == 'shellcmd' and entry.is_file():
                            if has_wildcard and not entry.stat().st_mode & stat.S_IXUSR:
                                continue
                            elif not has_wildcard and not os.access(entry, os.X_OK):
                                continue
                        if has_wildcard and Path(entry) == Path(path_prefix):
                            continue
                        if is_file_in_path and directory == '**' and Path(entry) == Path(cwd):
                            continue

                        if is_file_in_path:
                            # iglob and scandir return different types
                            entry_name = str(entry) if has_wildcard else entry.path
                            entry_name = self.get_path_relative_to_cwd(entry_name, cwd)
                        else:
                            entry_name = str(entry) if has_wildcard else entry.name

                        if entry.is_dir():
                            entry_name += os.sep
                        if entry_name in seen_files:
                            continue
                        seen_files.add(entry_name)

                        res.append(entry_name)
                    except OSError:
                        pass
            res = sorted(res)

            if not original_has_wildcard and not is_file_in_path:
                head = os.path.dirname(expand_arg)
                res = list(map(lambda f: os.path.join(head, f) if head else f, res))

            if expand_arg == '.':
                res.insert(0, '../')
                res.insert(0, './')
            elif expand_arg == '..':
                res.insert(0, '../')

            self.resolve(ctx, res)
        except Exception as e:
            self.reject(ctx, 'python_get_file_completion: ' + str(e))

    # Returns True if p2 is a descendant of p1
    def is_descendant_path(self, p1, p2):
        return os.path.relpath(p2, p1)[0:2] != '..'

    def get_basename(self, f, is_dir):
        if is_dir:
            return os.path.basename(f[:-1]) + os.sep
        return os.path.basename(f)

    def get_path_relative_to_cwd(self, p, cwd):
        if not self.is_descendant_path(cwd, p):
            return p

        p = os.path.relpath(p, cwd)
        if not p.startswith('/'):
            p = os.path.join('.', p)
        return p

    @neovim.function('_wilder_python_get_help_tags', sync=False, allow_nested=True)
    def _get_help_tags(self, args):
        self.run_in_background(self.get_help_tags_handler, args)

    def get_help_tags_handler(self, event, ctx, rtp, helplang):
        try:
            result = None
            with self.help_tags_lock:
                if ctx['session_id'] > self.help_tags_session_id:
                    self.help_tags_session_id = ctx['session_id']

                    if self.help_tags_result is not None:
                        self.help_tags_result['kill'].set()

                    self.help_tags_result = None

                if self.help_tags_result is not None:
                    result = self.help_tags_result
                else:
                    kill_event = threading.Event()
                    done_event = threading.Event()
                    result = {'kill': kill_event, 'done': done_event}
                    self.help_tags_result = result
                    self.executor.submit(functools.partial(self.get_help_tags_thread, result, rtp, helplang))
            while True:
                if result['done'].is_set():
                    break
                if event.wait(timeout=0.01):
                    return

            if 'error' in result:
                self.reject(ctx, 'python_get_help_tags: ' + result['error'])
                return

            self.resolve(ctx, result['tags'])
        except Exception as e:
            self.reject(ctx, 'python_get_help_tags: ' + str(e))

    def get_help_tags_thread(self, result, rtp, helplang):
        try:
            directories = rtp.split(',')

            if not helplang:
                langs = ['en']
            else:
                langs = helplang.split(',')
                if not 'en' in langs:
                    langs.append('en')

            default_lang = langs[0]

            lang_tags_dict = dict()
            tag_counter = Counter()

            for lang in langs:
                lang_tags_dict[lang] = set()

            checker = EventChecker(result['kill'])

            for directory in directories:
                tags_path = os.path.join(directory, 'doc', 'tags*')
                it = glob.iglob(tags_path)

                for name in it:
                    if checker.check():
                        return

                    tail = os.path.basename(name)
                    if tail == 'tags':
                        lang = 'en'
                    # tags-zz
                    elif len(tail) == 7 and tail.startswith('tags-'):
                        lang = tail[5:7]
                    else:
                        continue

                    if lang not in langs:
                        langs.append(lang)

                    if lang not in lang_tags_dict:
                        lang_tags_dict[lang] = set()

                    if not os.path.isfile(name) or not os.access(name, os.R_OK):
                        continue

                    try:
                        with open(name, 'r') as f:
                            for line in f.readlines():
                                if line.startswith('!_TAG_'):
                                    continue
                                columns = line.split("\t")
                                if not len(columns):
                                    continue

                                tag = columns[0]
                                tag_counter.update([tag])

                                lang_tags_dict[lang].add(tag)
                    except UnicodeDecodeError:
                        continue
                    except IOError:
                        continue

            tags = list(lang_tags_dict[default_lang])

            for lang in lang_tags_dict:
                if lang == default_lang:
                    continue

                lang_tags = lang_tags_dict[lang]

                for tag in lang_tags:
                    if tag in lang_tags_dict[default_lang]:
                        continue
                    elif tag_counter.get(tag) == 1:
                        tags.append(tag)
                    else:
                        tags.append(tag + '@' + lang)

            result['tags'] = sorted(tags)
        except Exception as e:
            result['error'] = str(e)
        finally:
            result['done'].set()

    @neovim.function('_wilder_python_get_users', sync=False, allow_nested=True)
    def _get_users(self, args):
        self.run_in_background(self.get_users_handler, args)

    def get_users_handler(self, event, ctx, expand_arg, expand_type):
        if event.is_set():
            return

        if os.name == 'nt':
            self.resolve(ctx, [])
            return

        try:
            res = []

            pwd = importlib.import_module('pwd')
            for user in pwd.getpwall():
                if user.pw_name.startswith(expand_arg):
                    res.append(user.pw_name)

            res = sorted(res)
            self.resolve(ctx, res)
        except Exception as e:
            self.reject(ctx, 'python_get_users: ' + str(e))

    @neovim.function('_wilder_python_fuzzy_filt', sync=False, allow_nested=True)
    def _fuzzy_filt(self, args):
        self.run_in_background(self.fuzzy_filt_handler, args)

    def fuzzy_filt_handler(self, event, ctx, *args):
        try:
            candidates = list(self.fuzzy_filt(event, *args))

            if event.is_set():
                return

            self.resolve(ctx, candidates)
        except Exception as e:
            self.reject(ctx, 'python_fuzzy_filt: ' + str(e))

    # case_sensitive: 0 - case insensitive
    #                 1 - case sensitive
    #                 2 - smartcase - x matches x|X, X matches X
    def make_fuzzy_pattern(self, query, case_sensitive=2):
        chars = list(query)
        pattern = '(?i)' if not case_sensitive else ''

        first = True
        for char in chars:
            if not first:
                pattern += '.*?'
            first = False

            if char == '\\':
                pattern += '\\\\'
            elif (char == '.' or
                    char == '^' or
                    char == '$' or
                    char == '*' or
                    char == '+' or
                    char == '?' or
                    char == '|' or
                    char == '(' or
                    char == ')' or
                    char == '{' or
                    char == '}' or
                    char == '[' or
                    char == ']'):
                pattern += '\\' + char + ''
            else:
                if case_sensitive == 2:
                    if char.isupper():
                        pattern += char
                    else:
                        pattern += '(' + char + '|' + char.upper() + ')'
                else:
                    pattern += char

        return pattern

    def fuzzy_filt(self, event, opts, candidates, pattern):
        engine = opts['engine'] if 'engine' in opts else 're'
        re = importlib.import_module(engine)
        # re2 does not use re.UNICODE by default
        pattern = re.compile(pattern, re.UNICODE)

        checker = EventChecker(event)
        for candidate in candidates:
            if checker.check():
                return

            if pattern.search(candidate):
                yield candidate

    @neovim.function('_wilder_python_fruzzy_filt', sync=False, allow_nested=True)
    def _fruzzy_filt(self, args):
        self.run_in_background(self.fruzzy_filt_handler, args)

    def fruzzy_filt_handler(self, event, ctx, *args):
        try:
            candidates = list(self.fruzzy_filt(event, *args))

            if event.is_set():
                return

            self.resolve(ctx, candidates)
        except Exception as e:
            self.reject(ctx, 'python_fruzzy_filt: ' + str(e))

    def fruzzy_filt(self, *args):
        opts = args[1]

        if 'fruzzy_path' in opts:
            self.add_sys_path(opts['fruzzy_path'])

        use_native = opts['use_native'] if 'use_native' in opts else False
        if use_native:
            return self.fruzzy_filt_native(*args)

        return self.fruzzy_filt_py(*args)

    def fruzzy_filt_native(self, event, opts, candidates, query):
        fruzzy_mod = importlib.import_module('fruzzy_mod')
        limit = opts['limit'] if 'limit' in opts else 1000

        indexes = fruzzy_mod.scoreMatchesStr(query, candidates, '', limit)

        sorted_matches = []
        for index, score in indexes:
            sorted_matches.append(candidates[index])

        return sorted_matches

    def fruzzy_filt_py(self, event, opts, candidates, query):
        fruzzy = importlib.import_module('fruzzy')
        limit = opts['limit'] if 'limit' in opts else 1000

        matches = fruzzy.fuzzyMatches(query, candidates, '', limit)

        checker = EventChecker(event)
        arr = []
        for match in matches:
            if checker.check():
                return
            arr.append(match)

        sorted_matches = heapq.nlargest(limit, arr, key=lambda i: i[5])

        return [match[0] for match in sorted_matches]

    @neovim.function('_wilder_python_cpsm_filt', sync=False, allow_nested=True)
    def _cpsm_filt(self, args):
        self.run_in_background(self.cpsm_filt_handler, args)

    def cpsm_filt_handler(self, event, ctx, *args):
        try:
            candidates = list(self.cpsm_filt(event, *args))

            if event.is_set():
                return

            self.resolve(ctx, candidates)
        except Exception as e:
            self.reject(ctx, 'python_cpsm_filt: ' + str(e))

    def cpsm_filt(self, event, opts, candidates, query):
        if not candidates:
            return candidates

        if 'cpsm_path' in opts:
            self.add_sys_path(opts['cpsm_path'])

        ispath = opts['ispath'] if 'ispath' in opts else False

        cpsm = importlib.import_module('cpsm_py')
        return cpsm.ctrlp_match(candidates, query, ispath=ispath)[0]

    @neovim.function('_wilder_python_clap_filt', sync=False, allow_nested=True)
    def _clap_filt(self, args):
        self.run_in_background(self.clap_filt_handler, args)

    def clap_filt_handler(self, event, ctx, *args):
        try:
            candidates = list(self.clap_filt(event, *args))

            if event.is_set():
                return

            self.resolve(ctx, candidates)
        except Exception as e:
            self.reject(ctx, 'python_clap_filt: ' + str(e))

    def clap_filt(self, event, opts, candidates, query):
        if not candidates:
            return candidates

        if 'clap_path' in opts:
            clap_path_head = os.path.split(opts['clap_path'])[0]
            self.add_sys_path(clap_path_head)

        use_rust = opts['use_rust'] if 'use_rust' in opts else False

        if use_rust:
            fuzzymatch_rs = importlib.import_module('clap.fuzzymatch_rs')
            result = fuzzymatch_rs.fuzzy_match(query, candidates, [], {'winwidth': '0'})
            return result[1]
        else:
            scorer = importlib.import_module('clap.scorer')

            result = []
            NO_MATCH = float("-inf")
            checker = EventChecker(event)
            for candidate in candidates:
                if checker.check():
                    return

                score, indices = scorer.fzy_scorer(query, candidate)
                if score != NO_MATCH:
                    result.append((candidate, score))

            result.sort(key=lambda x: x[1], reverse=True)
            return map(lambda x: x[0], result)

    @neovim.function('_wilder_python_difflib_sort', sync=False, allow_nested=True)
    def _difflib_sort(self, args):
        self.run_in_background(self.difflib_sort_handler, args)

    def difflib_sort_handler(self, event, ctx, *args):
        if event.is_set():
            return

        try:
            candidates = list(self.difflib_sort(event, *args))

            if event.is_set():
                return

            self.resolve(ctx, candidates)
        except Exception as e:
            self.reject(ctx, 'python_difflib_sort: ' + str(e))

    def difflib_sort(self, event, opts, candidates, query):
        quick = opts['quick'] if 'quick' in opts else True
        case_sensitive = opts['case_sensitive'] if 'case_sensitive' in opts else True

        xs = [None] * len(candidates)
        checker = EventChecker(event)
        for index, candidate in enumerate(candidates):
            if checker.check():
                return

            if case_sensitive:
                matcher = difflib.SequenceMatcher(None, candidate, query)
            else:
                matcher = difflib.SequenceMatcher(None, candidate.lower(), query.lower())
            score = -matcher.quick_ratio() if quick else -matcher.ratio()
            xs[index] = (candidate, score,)

        return [x[0] for x in sorted(xs, key=lambda x: x[1])]

    @neovim.function('_wilder_python_fuzzywuzzy_sort', sync=False, allow_nested=True)
    def _fuzzywuzzy_sort(self, args):
        self.run_in_background(self.fuzzywuzzy_sort_handler, args)

    def fuzzywuzzy_sort_handler(self, event, ctx, *args):
        try:
            candidates = list(self.fuzzywuzzy_sort(event, *args))

            if event.is_set():
                return

            self.resolve(ctx, candidates)
        except Exception as e:
            self.reject(ctx, 'python_fuzzywuzzy_sort: ' + str(e))

    def fuzzywuzzy_sort(self, event, opts, candidates, query):
        fuzzy = importlib.import_module('fuzzywuzzy.fuzz')
        partial = opts['partial'] if 'partial' in opts else True
        ratio = fuzzy.partial_ratio if partial else fuzzy.ratio

        xs = [None] * len(candidates)
        checker = EventChecker(event)
        for index, candidate in enumerate(candidates):
            if checker.check():
                return []

            xs[index] = (candidate, -ratio(candidate, query),)

        return [x[0] for x in sorted(xs, key=lambda x: x[1])]

    @neovim.function('_wilder_python_basic_highlight', sync=True)
    def _basic_highlight(self, args):
        string = args[0]
        query = args[1]
        case_sensitive = args[2]

        if not case_sensitive:
            string = string.upper()
            query = query.upper()

        spans = []
        span = [-1, 0]

        byte_pos = 0
        i = 0
        j = 0
        while i < len(string) and j < len(query):
            match = string[i] == query[j]

            if match:
                j += 1

                if span[0] == -1:
                    span[0] = byte_pos
                span[1] += len(string[i].encode('utf-8'))

            if not match and span[0] != -1:
                spans.append(span)
                span = [-1, 0]

            byte_pos += len(string[i].encode('utf-8'))
            i += 1

        if span[0] != -1:
            spans.append(span)

        return spans

    @neovim.function('_wilder_python_pcre2_highlight', sync=True)
    def _pcre2_highlight(self, args):
        pattern = args[0]
        string = args[1]
        module_name = args[2]

        re = importlib.import_module(module_name)
        match = re.search(pattern, string)

        if not match or not match.lastindex:
            return 0

        captures = []
        for i in range(1, match.lastindex + 1):
            start = match.start(i)
            end = match.end(i)
            if start == -1 or end == -1 or start == end:
                continue

            byte_start = len(string[: start].encode('utf-8'))
            byte_len = len(string[start : end].encode('utf-8'))
            captures.append([byte_start, byte_len])

        return captures

    @neovim.function('_wilder_python_cpsm_highlight', sync=True)
    def _cpsm_highlight(self, args):
        opts = args[0]
        x = args[1]
        query = args[2]

        if 'cpsm_path' in opts:
            self.add_sys_path(opts['cpsm_path'])

        ispath = opts['ispath'] if 'ispath' in opts else False
        highlight_mode = opts['highlight_mode'] if 'highlight_mode' in opts else 'basic'

        cpsm = importlib.import_module('cpsm_py')
        match = cpsm.ctrlp_match([x], query, ispath=ispath, highlight_mode=highlight_mode, unicode=True)

        if not match[0]:
            return 0

        vim_highlights = match[1]
        pattern = re.compile('\\\\zs(.*)\\\\ze', re.UNICODE)

        spans = []
        for vim_highlight in vim_highlights:
            match = pattern.search(vim_highlight)
            if match:
                start, end = match.span(1)
                byte_start = len(x[: start - 9].encode('utf-8'))
                byte_len = len(x[start - 9 : end - 9].encode('utf-8'))
                spans.append((byte_start, byte_len))

        return spans

class EventChecker:
    def __init__(self, event, interval_s=0.1):
        self.event = event
        self.interval_s = interval_s
        self.last_check = time.time()

    def check(self):
        now = time.time()
        if now - self.last_check < self.interval_s:
            return False

        self.last_check = now
        return self.event.is_set()
