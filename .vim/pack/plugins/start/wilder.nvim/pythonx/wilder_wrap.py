from wilder import Wilder as _Wilder
import vim

_obj = _Wilder(vim)

def _init(args):
    return _obj._init(args)

def _file_finder(args):
    return _obj._file_finder(args)

def _sleep(args):
    return _obj._sleep(args)

def _search(args):
    return _obj._search(args)

def _uniq_filt(args):
    return _obj._uniq_filt(args)

def _lexical_sort(args):
    return _obj._lexical_sort(args)

def _get_file_completion(args):
    return _obj._get_file_completion(args)

def _get_help_tags(args):
    return _obj._get_help_tags(args)

def _get_users(args):
    return _obj._get_users(args)

def _fuzzy_filt(args):
    return _obj._fuzzy_filt(args)

def _fruzzy_filt(args):
    return _obj._fruzzy_filt(args)

def _cpsm_filt(args):
    return _obj._cpsm_filt(args)

def _difflib_sort(args):
    return _obj._difflib_sort(args)

def _fuzzywuzzy_sort(args):
    return _obj._fuzzywuzzy_sort(args)

def _basic_highlight(args):
    return _obj._basic_highlight(args)

def _pcre2_highlight(args):
    return _obj._pcre2_highlight(args)

def _cpsm_highlight(args):
    return _obj._cpsm_highlight(args)
