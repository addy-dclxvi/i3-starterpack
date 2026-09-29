#!/usr/bin/env python3
# encoding: utf-8
import json
import vim
import re
import os
import hashlib
import platform

SNIPPETS_FILES_CTX = {}
ALWAYS = 'always'
NEVER = 'never'

def is_macos():
    if platform.system() == "Darwin":
        return 'v:true'
    else:
        return 'v:false'

def get_arch():
    arch = platform.machine()
    return arch

def listdir(path):
    ret = []
    try:
        ret = os.listdir(path)
    except FileNotFoundError:
        ret = []
    return ret


def get_sha256(str):
    s = hashlib.sha256()
    s.update(str.encode("utf8"))
    sha_str = s.hexdigest()
    return sha_str


# Normal sort
def _get_key(el):
    if len(el["abbr"]) != 0:
        k1 = el["abbr"]
    else:
        k1 = el["word"]
    return k1


def getkey_by_alphabet(el):
    return _get_key(el).lower().rjust(5, "a")


def getkey_by_length(el):
    return len(_get_key(el))


def json_parse_bool2str(obj):
    if obj is None:
        return ""
    if isinstance(obj, bool):
        return str(obj).lower()
    if isinstance(obj, (list, tuple)):
        return [json_parse_bool2str(item) for item in obj]
    if isinstance(obj, dict):
        its = obj.items()
        return {json_parse_bool2str(k): json_parse_bool2str(v) for k, v in its}
    return obj


def normalize_sort(items):
    # 先按照长度排序
    items.sort(key=getkey_by_length)
    # 再按照字母表排序
    items.sort(key=getkey_by_alphabet)
    return json.dumps(json_parse_bool2str(items), ensure_ascii=False)


# Fuzzy search
def fuzzy_search(needle, haystack):
    """
    判断是否符合模糊匹配的规则，实测性能不如 viml 的实现
    """
    # flag = 1
    tlen = len(haystack)
    qlen = len(needle)
    if qlen > tlen:
        return 0
    elif qlen == tlen:
        if needle == haystack:
            return 1
        else:
            return 0
    else:
        needle_ls = list(needle)
        haystack_ls = list(haystack)
        j = 0
        fallback = 0
        for nch in needle_ls:
            fallback = 0
            while j < tlen:
                if haystack_ls[j] == nch:
                    j += 1
                    fallback = 1
                    break
                else:
                    j += 1
            if fallback == 1:
                continue
            return 0
        return 1


def log(msg):
    print(msg)


# py vs vim，vim 性能极好
# 27 次调用，py 用时 0.012392
# 27 次调用，vim 用时0.002804
def snippets_code_info(filename, line_number):
    """
    根据文件路径和行号，从标准 snippets 格式中获得展开后的语义化的代码片段
    """
    if filename in SNIPPETS_FILES_CTX.keys():
        snip_ctx = SNIPPETS_FILES_CTX.get(filename, False)
    else:
        fo = open(filename, "r", encoding="utf-8-sig")
        snip_ctx = fo.readlines()
        SNIPPETS_FILES_CTX.setdefault(filename, snip_ctx)
        fo.close()

    cursor_line = line_number
    while cursor_line + 1 < len(snip_ctx):
        new_ln = cursor_line + 1
        if re.compile(r"^(snippet|endsnippet)").match(snip_ctx[new_ln]):
            break
        else:
            cursor_line += 1

    start_line_index = line_number
    end_line_index = cursor_line

    code_original_info = snip_ctx[start_line_index:end_line_index + 1]
    lam = map(lambda line: re.sub(r"\n$", "", line), code_original_info)
    ret_array = list(lam)
    # vim.command("echom %s"% json.dumps(ret_array))
    return json.dumps(ret_array, ensure_ascii=False)


def complete_menu_filter(all_menu, word, maxlength):
    return json.dumps(all_menu, ensure_ascii=False)


"""
Helper utilities to format javascript snippets.
"""
# {{{


def get_option(snip, option, default=None):
    return snip.opt('g:ultisnips_javascript["{}"]'.format(option), default)


def semi(snip):
    option = get_option(snip, 'semi', ALWAYS)

    if option == NEVER:
        ret = ''
    elif option == ALWAYS:
        ret = ';'
    else:
        ret = ';'
    return ret


def space_before_function_paren(snip):
    option = get_option(snip, 'space-before-function-paren', NEVER)

    if option == NEVER:
        ret = ''
    elif option == ALWAYS:
        ret = ' '
    else:
        ret = ''
    return ret


def keyword_spacing(snip):
    option = get_option(snip, 'keyword-spacing', ALWAYS)

    if option == NEVER:
        ret = ''
    elif option == ALWAYS:
        ret = ' '
    else:
        ret = ''
    return ret

# }}}

# vim:ts=4:sw=4:sts=4
