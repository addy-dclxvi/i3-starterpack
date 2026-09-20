// lua dependencies
use mlua::{Lua, Value, Table};
use mlua::prelude::*;
use serde_json;

// sumbline_fuzzy dependencies
use unicode_segmentation::UnicodeSegmentation;
use std::convert::TryInto;
use sublime_fuzzy::{FuzzySearch, Scoring};

// Log dependencies
use chrono::Local;
use std::fs::OpenOptions;
use std::io::Write;
use std::fmt::Debug;
use std::fmt;

// base64 两个基本函数
use base64::{encode, decode};

// 获得环境信息
use std::env;

fn console<T: Debug>(data: T) -> std::io::Result<()> {
    let home_dir = match env::var("HOME") {
        Ok(path) => path,             // macOS/Linux
        Err(_) => match env::var("USERPROFILE") {
            Ok(path) => path,         // Windows
            Err(_) => {
                panic!("无法确定主目录");
            }
        }
    };

    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(home_dir + "/.config/vim-easycomplete/debuglog")?;

    let now = Local::now();
    let timestamp = now.format("%Y-%m-%d %H:%M:%S").to_string();
    writeln!(file, "[{}] {:#?}", timestamp, data)?;
    Ok(())
}

#[derive(Debug, Clone)]
pub struct LspItem {
    pub label: String,
    pub kind: u32,
    pub word: String
}

// 标准 C 调用格式
#[unsafe(no_mangle)]
pub extern "C" fn add_old(a: i32, b: i32) -> i32 {
    a + b
}

// 只输出一个简单的字符串
fn hello(lua: &Lua, (a,b) : (String, String)) -> LuaResult<String> {
    // println!("xxxxx");
    Ok(a.to_string() + &b.to_string())
}

// 返回一个数组形式的 Table
fn return_table(lua: &Lua, _: ()) -> LuaResult<LuaTable> {
    let label: &str = "label";
    let word: &str = "word";
    let table = lua.create_table()?;
    let data = vec![10, 20, 30];
    for (i, value) in data.iter().enumerate() {
        table.set(i + 1, *value)?; // Lua 索引从 1 开始
    }
    Ok(table)
}

// 传入一个 lua table，操作键值对的 table
fn parse_table(lua: &Lua, table: LuaTable) -> LuaResult<LuaTable> {
    let ret_str : String = String::from("abc");
    table.set("xxx", ret_str);
    Ok(table)
}

// 返回一个键值对的 Table
fn return_kv_table(lua: &Lua, _: ()) -> LuaResult<LuaTable> {
    let table = lua.create_table()?;
    table.set("aaa",1)?;
    table.set("bbb","new_string")?;
    Ok(table)
}

// 将一个数字组成的数组Table 转换为 slice
fn lua_table_to_usize_slice(lua: &Lua, table: LuaTable) -> Result<Vec<usize>, LuaError> {
    // 创建一个 Vec 来存储 usize 值
    let mut vec = Vec::new();

    // 遍历 Lua 表中的所有键值对
    for pair in table.pairs::<mlua::Integer, mlua::Integer>() {
        let (key, value) = pair?;
        if key >= 1 && value >= 0 {
            // 将 Lua Integer 转换为 usize 并添加到 Vec 中
            vec.push(value as usize);
        }
    }

    Ok(vec)
}

// 读取 lua 中的全局变量
fn get_global_vars(lua: &Lua, _: ()) -> LuaResult<i32> {
    let globals = lua.globals();
    lua.globals().set("my_global_var", "Hello from Lua!")?;
    let my_global_var: i32 = globals.get("easycomplete_pum_maxlength")?;
    Ok(my_global_var)
}

// 先更新全局变量，然后读取全局变量
fn get_first_complete_hit(lua: &Lua, _:()) -> LuaResult<i32> {
    let globals = lua.globals();
    update_global_lua_vars(lua);
    let ret: i32 = globals.get("easycomplete_first_complete_hit")?;
    Ok(ret)
}

// 更新有用的lua全局变量
fn update_global_lua_vars(lua: &Lua) -> LuaResult<String> {
    let globals = lua.globals();
    let init_global_vars: mlua::Function = globals.get("init_global_vars_for_rust")?;
    init_global_vars.call::<()>("default")?;
    Ok("abc".to_string())
}

// 实现 Lua 版本的 `util.parse_abbr`
//
// 参数:
// - `abbr`: 要处理的字符串
// - `max_length`: 最大显示长度 (对应 vim.g.easycomplete_pum_maxlength)
// - `fix_width`: 是否固定宽度 (对应 vim.g.easycomplete_pum_fix_width == 1)
//
// 返回: 处理后的字符串
fn parse_abbr(lua: &Lua, abbr: String) -> LuaResult<String> {
    let globals = lua.globals();
    // let init_global_vars: mlua::Function = globals.get("init_global_vars_for_rust")?;
    // init_global_vars.call("default")?; // 不需要每次都更新
    let max_length_i32: i32 = globals.get("easycomplete_pum_maxlength")?;
    let fix_width_i32: i32 = globals.get("easycomplete_pum_fix_width")?;
    let max_length: usize = max_length_i32.try_into().expect("i32 value cannot fit in usize");
    let fix_width: bool = match fix_width_i32 {
        1 => true,
        0 => false,
        _ => panic!("fix_width must be 0 or 1!"),
    };
    let abbr_obj = Abbr::new(&abbr, max_length, fix_width);
    // console(&abbr_obj);
    let ret: String = abbr_obj.get_parsed_abbr().unwrap();

    Ok(ret)
}

// Abbr Struct
// #[derive(Debug)]
struct Abbr {
    abbr:  String,
    chars: Vec<char>,
    short: String,
    max_length: usize,
    symble: char,
    fix_width: bool
}

impl fmt::Debug for Abbr {
    fn fmt(&self, fmt: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt.debug_struct("Abbr")
            .field("abbr", &self.abbr)
            .field("chars", &self.chars)
            .field("max_length", &self.max_length)
            .field("symble", &self.symble)
            .field("fix_width", &self.fix_width)
            .finish()
    }
}

impl Abbr {
    fn new(o_abbr: &str, max_length: usize, fix_width: bool) -> Self {
        let symble: char = '…';
        let abbr: String = o_abbr.to_string().clone();
        let chars: Vec<char> = o_abbr.chars().collect();
        let max_length: usize = max_length;
        let fix_width: bool = fix_width;
        let short: String = String::from("");

        let mut this = Self {
            abbr:       abbr,
            symble:     symble,
            chars:      chars,
            max_length: max_length,
            fix_width:  fix_width,
            short:      short
        };

        this.produce();
        this
    }

    fn produce(&mut self) -> Result<bool, ()>{
        let abbr_chars: Vec<char> = self.chars.clone();
        let abbr_len: usize = abbr_chars.len() as usize;
        let max_length: usize = self.max_length;
        let fix_width: bool = self.fix_width;
        let symble: char = self.symble;
        let mut short: String = String::from("");

        if abbr_len <= max_length {
            let abbr: String = abbr_chars.into_iter().collect();
            if fix_width {
                // 右填充空格到 max_length
                let spaces = " ".repeat(max_length - abbr_len);
                short = format!("{}{}", abbr, spaces);
            } else {
                short = abbr.to_string();
            }
        } else {
            // 截取前 max_length - 1 个字符，加上 "…"
            let truncated: String = abbr_chars.into_iter().take(max_length - 1).collect();
            short = format!("{}{}", truncated, symble)
        }
        self.short = short;
        Ok(true)
    }

    fn get_parsed_abbr(&self) -> Result<String, ()> {
        Ok(self.short.clone())
    }
}

// 重写 lua 版本的 util.replacement()
// 参数：
// - abbr: 对应 item 的 abbr, String 类型
// - positions: matchfuzzy 的 position 数组，LuaTable 类型
// - wrap_char: 包裹字符，char 类型
//
// 返回：返回根据 positions 里所示位置的字符加上了
// 包裹wrap_char的结果字符串
fn replacement(lua: &Lua, (abbr, positions, wrap_char) : (mlua::String, LuaTable, char)) -> LuaResult<String> {
    let t_abbr: String = abbr.to_string_lossy();
    let result_positions: Result<Vec<usize>, LuaError> = lua_table_to_usize_slice(lua, positions);
    let mut t_positions: Vec<usize> = result_positions.unwrap();
    let ret_str: String = _replacement(&t_abbr, &t_positions, wrap_char);
    Ok(ret_str)
}

fn _replacement(abbr: &str, positions: &[usize], wrap_char: char) -> String {
    // 将字符串按 Unicode 字符（grapheme clusters）拆分为 Vec<String>
    let chars: Vec<&str> = abbr
        .graphemes(true)
        .collect();

    // 检查 positions 是否越界
    if chars.is_empty() {
        return abbr.to_string();
    }

    let mut result_chars: Vec<String> = chars.iter().map(|&s| s.to_string()).collect();

    // 对每个指定的位置进行包裹
    for &idx in positions {
        if idx < result_chars.len() {
            result_chars[idx] = format!("{}{}{}", wrap_char, result_chars[idx], wrap_char);
        }
    }

    // 合并成一个字符串
    let mut result = result_chars.concat();

    // 移除连续的 wrap_char（如 **）
    let double_wrap = format!("{}{}", wrap_char, wrap_char);
    result = result.replace(&double_wrap, "");

    result
}

// 判断 luatable 中的某个键是否为 nil
fn is_key_nil(table: LuaTable, key: &str) -> bool {
    // 尝试获取指定键的值
    let ret: bool = table.contains_key(key).unwrap();
    ret
}

// 根据Table元素里的word字段进行长度排序
// 参数：table，待排序的 luatable
// 返回：排序之后的table
fn sort_table_by_word_len(lua: &Lua, mut table: Table) -> Result<LuaTable, LuaError> {
    // 1. 提取所有元素
    let mut items: Vec<Table> = table
        .sequence_values::<Table>()
        .collect::<Result<Vec<_>, _>>()?;

    // 2. 在 Rust 中排序
    items.sort_by(|a, b| {
        let name_a = a.get::<String>("word").unwrap_or_default();
        let name_b = b.get::<String>("word").unwrap_or_default();
        name_a.len().cmp(&name_b.len()) // 升序
    });

    // 3. 清空原 table
    for i in 1..=table.raw_len() {
        table.set(i, Value::Nil)?;
    }

    // 4. 写回排序后的结果
    for (i, item) in items.into_iter().enumerate() {
        table.set(i + 1, item)?; // Lua 索引从 1 开始
    }

    Ok(table)
}

// 重写 lua 版本的 complete_menu_filter 函数，重点做着色
// lua → util.complete_menu_filter(matching_res, word)
// 这里只在 rust 内被调用，通常不会被lua直接调用
// 参数：
// - matching_res: 待做匹配的原数组
// - word: 匹配单词
// 返回：匹配结束的数组
fn complete_menu_filter(
    lua: &Lua,
    (matching_res, word): (LuaTable, String))
-> LuaResult<LuaTable> {
    let globals = lua.globals();
    let mut fullmatch_result = lua.create_table()?;
    let mut firstchar_result = lua.create_table()?;
    let mut fuzzymatch_result = lua.create_table()?;

    let fuzzymatching: LuaTable = matching_res.get(1)?;
    let fuzzy_position: LuaTable = matching_res.get(2)?;
    let fuzzy_scores: LuaTable = matching_res.get(3)?;

    let mut iter = fuzzymatching.sequence_values::<Table>();
    let mut i: usize = 1;
    while let Some(every_item) = iter.next() {
        let item = every_item?;

        if is_key_nil(item.clone(), "abbr") {
            let t_abbr: String = item.get("abbr")?;
            let t_word: String = item.get("word")?;
            if t_abbr == "" {
                item.set("abbr", t_word)?;
            }
        }

        let o_abbr: String = item.get("abbr")?;
        let abbr_rust_str: String = parse_abbr(lua, o_abbr)?;
        let abbr_lua_str = lua.create_string(&abbr_rust_str)?;
        item.set("abbr", abbr_rust_str)?;
        let p: LuaTable = fuzzy_position.get(i)?;
        let abbr_replacement: String = replacement(lua, (abbr_lua_str, p.clone(), '§'))?;
        let item_score: i32 = fuzzy_scores.get(i)?;

        item.set("abbr_marked", abbr_replacement)?;
        item.set("marked_position", p)?;
        item.set("score", item_score)?;

        let item_word: String = item.get("word")?;
        let item_word_lower: String = item_word.clone().to_lowercase();
        let word_lower: String = word.clone().to_lowercase();

        if item_word_lower == word_lower {
            fullmatch_result.raw_insert(1, item.clone());
        } else if item_word_lower.starts_with(&word_lower) {
            fullmatch_result.push(item.clone());
        // sumbline_fuzzy 排序结果已经考虑到首字母匹配靠前排序了，这里应该不是必须了
        // } else if item_word_lower.chars().next() == word_lower.chars().next() {
        //     firstchar_result.push(item.clone());
        } else {
            fuzzymatch_result.push(item.clone());
        }

        i += 1;
    }
    // local stunt_items = vim.fn["easycomplete#GetStuntMenuItems"]()
    update_global_lua_vars(lua);
    // 数组形式的 table
    let stunt_items: LuaTable = globals.get("easycomplete_stunt_menuitems")?;
    let stunt_items_len_i64: i64 = stunt_items.len()?;
    let stunt_items_len_i32: i32 = stunt_items_len_i64.try_into().unwrap();

    let first_complete_hit: i32 = globals.get("easycomplete_first_complete_hit")?;
    let mut sorted_fuzzymatch_result: LuaTable;
    if stunt_items_len_i32 == 0 && first_complete_hit == 1 {
        sorted_fuzzymatch_result = sort_table_by_word_len(lua, fuzzymatch_result.clone())?;
    } else {
        sorted_fuzzymatch_result = fuzzymatch_result.clone();
    }

    // 将几个数组合并到一起 [A..] + [B..] + [C..]
    let mut tmp_items = Vec::new();
    // 提取所有元素，依次合并
    tmp_items.extend(fullmatch_result.sequence_values::<mlua::Value>().collect::<Result<Vec<_>,_>>()?);
    tmp_items.extend(firstchar_result.sequence_values::<mlua::Value>().collect::<Result<Vec<_>,_>>()?);
    tmp_items.extend(fuzzymatch_result.sequence_values::<mlua::Value>().collect::<Result<Vec<_>,_>>()?);

    // 创建新的 Lua table 并写入
    let filtered_menu = lua.create_table()?;
    for (i, item) in tmp_items.into_iter().enumerate() {
        filtered_menu.set(i + 1, item)?; // Lua 索引从 1 开始
    }

    Ok(filtered_menu)
}

// 函数弃用
// util.badboy_vim(item, typing_word) 的 rust 实现
// 200 个节点的循环次数：
//  - lua: 6ms
//  - rust: 8ms
fn badboy_vim(lua: &Lua, (item, typing_word): (LuaTable, String)) -> LuaResult<bool> {
    let mut word: String;
    if is_key_nil(item.clone(), "label") {
        word = item.get("label")?;
    } else {
        word = "".to_string();
    }
    word = item.get("label")?;
    if word.chars().count() == 0 {
        return Ok(true);
    } else if typing_word.chars().count() == 1 {
        let first_char: char = typing_word.chars().next().unwrap_or_default();
        let pos: i32;
        match word.find(first_char) {
            Some(position) => {
                pos = position.try_into().unwrap();
            },
            None => {
                pos = -1;
            },
        }
        if pos >= 0 && pos <= 5 {
            return Ok(false);
        } else {
            return Ok(true);
        }
    } else {
        if fuzzy_search(&typing_word, &word) {
            return Ok(false);
        } else {
            return Ok(true);
        }
    }
}

// 重写 fuzzy_search，只做模糊匹配，不算得分，和 lua 里保持一致
// 只在做少量匹配时使用，大量匹配时仍应使用 sumbline_fuzzy
// fuzzy_search("AsyncController","ac") true
fn fuzzy_search(haystack: &str, needle: &str) -> bool {
    let mut haystack_chars = haystack.chars();

    for n in needle.chars() {
        // 在 haystack 中查找当前 needle 字符
        let mut found = false;
        while let Some(h) = haystack_chars.next() {
            if n.eq_ignore_ascii_case(&h) {
                found = true;
                break;
            }
        }
        if !found {
            return false;
        }
    }
    true
}

// 根据 `word` 的长度，筛选出最短的 n 个元素
// util.trim_array_to_length 的 rust 实现
// arr: 原 all_items_list， 是数组形式的 table
fn trim_array_to_length(lua: &Lua, (arr, n): (LuaTable, i32)) -> Result<LuaTable, LuaError> {
    let n = n as usize;

    // 获取数组长度
    let len = arr.raw_len().try_into().expect("i32 value cannot fit in usize");
    if len <= n {
        return Ok(arr); // 返回原表
    }

    // 遍历数组形式的 LuaTable 的常用写法
    let mut indexed = Vec::with_capacity(len);
    let mut iter = arr.sequence_values::<Table>();
    let mut i: usize = 1;
    while let Some(every_item) = iter.next() {
        let item = every_item?;
        let t_word: String = item.get("word")?;
        if let word = t_word {
            indexed.push((i, word.len()));
        } else {
            // 如果没有 word 字段，给一个大长度避免优先选中
            indexed.push((i, usize::MAX));
        }
        i += 1;
    }

    // 按 word 长度升序排序（稳定排序）
    indexed.sort_by_key(|&(_, len)| len);

    // 创建结果表
    let ret = lua.create_table()?;
    for (pos, (orig_idx, _)) in indexed.into_iter().take(n).enumerate() {
        // 使用原始索引从 arr 取出完整元素
        let value: LuaTable = arr.get(orig_idx)?;
        ret.set(pos + 1, value)?; // Lua 表索引从 1 开始
    }

    Ok(ret)
}

// lua 做 item fuzzy match 的调用入口，替代原生的 matchfuzzypos
// 参数：
// - key_name: 匹配字段，abbr 还是 word
fn complete_menu_fuzzy_filter(lua: &Lua,
    (all_menu, word, key_name, maxlength): (LuaTable, String, String, i32)) -> Result<LuaTable, LuaError> {

    let all_items: LuaTable = trim_array_to_length(lua, (all_menu, maxlength + 130))?;
    let opt: LuaTable = lua.create_table()?;
    opt.set("key", key_name.to_string())?;
    opt.set("limit", maxlength)?;
    let mut matching_res: LuaTable = matchfuzzypos(lua, (all_items, word.clone(), opt))?;
    let mut ret: LuaTable = complete_menu_filter(lua, (matching_res, word.clone()))?;
    // console(&ret);
    Ok(ret)
}

// https://crates.io/crates/sublime_fuzzy
// 耗时 6ms，比 lua 快 2ms
// 参数：
//  - maxlength: 通常设置 350
//  - list: 原始数组
//  - word: 匹配单词
//  - opt:  参照matchfuzzypos 的第三个参数格式，这里只用到了
//          key和limit这两个参数
fn matchfuzzypos(lua: &Lua, (list, word, opt): (LuaTable, String, LuaTable)) -> Result<LuaTable, LuaError> {
    let mut matchfuzzy = lua.create_table()?;
    let mut positions = lua.create_table()?;
    let mut scores = lua.create_table()?;
    let key: String = opt.get("key")?;
    let limit: i32 = opt.get("limit")?;

    let scoring = Scoring {
        // bonus_consecutive: 200,
        // bonus_word_start: 10,
        // penalty_distance: 5,
        // bonus_match_case: 100,
        ..Scoring::default()
    };

    let mut list_iter = list.sequence_values::<Table>();
    let mut i: usize = 1;
    while let Some(every_item) = list_iter.next() {
        let mut item = every_item?;
        let t_word: String = item.get(key.clone())?;
        let mut position: LuaTable = lua.create_table()?;
        let mut score: i32;
        let match_result = FuzzySearch::new(&word, &t_word)
                            // .case_sensitive() // 不需要大小写敏感
                            .score_with(&scoring)
                            .best_match();
        match match_result {
            Some(m) => {
                if m.matched_indices().len() == word.chars().count() {
                    // match
                    for p in m.matched_indices() {
                        position.push(*p as i32);
                    }
                    score = m.score() as i32;

                    item.set("score", score.clone());
                    item.set("position", position.clone());
                    matchfuzzy.push(item.clone());
                }
            }
            None => {
                // catch exception
                // do nothing and continue
            }
        }
        i += 1;
    }

    // matchfuzzy 转换为向量
    let mut matchfuzzy_vec: Vec<Table> = matchfuzzy
        .sequence_values::<Table>()
        .collect::<Result<Vec<_>, _>>()?;

    matchfuzzy_vec.sort_by(|a, b| {
        let score_a = a.get::<i32>("score").unwrap_or_default();
        let score_b = b.get::<i32>("score").unwrap_or_default();
        let word_a = a.get::<String>("word").unwrap_or_default();
        let word_b = b.get::<String>("word").unwrap_or_default();
        // 先按照分数排序，再按照长度排序
        score_b.cmp(&score_a).then_with(|| word_a.len().cmp(&word_b.len()))
    });

    let mut new_matchfuzzy = lua.create_table()?;

    // 写回排序后的结果
    for (i, item) in matchfuzzy_vec.into_iter().enumerate() {
        let mut p: LuaTable = item.get("position")?;
        let mut s: i32 = item.get("score")?;
        new_matchfuzzy.set(i+1, item)?; // Lua 索引从 1 开始
        positions.set(i+1, p.clone())?;
        scores.set(i+1, s.clone())?;

        if i > limit as usize  {
            break;
        }
    }

    let mut result = lua.create_table()?;
    result.push(new_matchfuzzy);
    result.push(positions);
    result.push(scores);
    Ok(result)
}

// 161 个元素的遍历，lua 10ms，rust 5ms, vim 15ms
// 只做对 buf keyword 的 raw 格式的封装
// 参数同 lua
//
// 返回：完整的封装好的列表，列表会被缓存到全局对象中
fn final_normalize_menulist(lua: &Lua,
    (arr, plugin_name): (LuaTable, String))
-> Result<LuaTable, LuaError> {
    let mut result: LuaTable = lua.create_table()?;
    let cloned_plugin_name: &str = &plugin_name.clone();
    let arr_len: usize = arr.raw_len().try_into().expect("final len error");
    if arr_len == 0 {
        return Ok(result);
    } else if plugin_name == "snips" {
        return Ok(arr);
    }
    // local l_menu_list = {}
    let l_menu_list : LuaTable = lua.create_table()?;

    let mut iter = arr.sequence_values::<Table>();
    while let Some(every_item) = iter.next() {
        let item = every_item?;
        let now = Local::now();
        let timestamp: u32 = now.timestamp_subsec_nanos();
        let timestamp_str = format!("{}", timestamp);
        let sha256_str = timestamp_str;
        // 时间戳就已经符合要求了，不用再强制做 base64 编码
        // let sha256_str = encode(timestamp_str.as_bytes());
        // console(&sha256_str);

        let r_user_data: LuaTable = lua.create_table()?;

        if cloned_plugin_name == "ts" {
            // 把ts里的user_data原有的字段存到r_user_data里
            let user_data_value: mlua::Value = item.get("user_data")?;
            if let mlua::Value::String(user_data_str) = user_data_value {
                let user_data_string = user_data_str.to_str()?;
                if !user_data_string.is_empty() {
                    // 原有处理逻辑
                    match serde_json::from_str::<serde_json::Value>(&user_data_string) {
                        Ok(user_data_json_value) => {
                            // console(&user_data_json_value);
                            if let serde_json::Value::Object(map) = user_data_json_value {
                                for (key, value) in map.iter() {
                                    let lua_value: mlua::Value = lua.to_value(value)?;
                                    r_user_data.set(&**key, lua_value)?;
                                }
                            }
                        }
                        Err(_) => {
                            // 如果JSON解析失败，可以选择记录日志或忽略错误
                        }
                    }
                }
            }
        }

        r_user_data.set("plugin_name", cloned_plugin_name)?;
        r_user_data.set("sha256", sha256_str)?;

        // 将 LuaTable 包装为 Value
        let r_user_data_value: Value = mlua::Value::Table(r_user_data.clone());

        // 使用 serde 转换为 JSON
        let json_raw_value: &str = &serde_json::to_string(&r_user_data_value).unwrap();
        let json_value: serde_json::Value = serde_json::from_str(json_raw_value).unwrap();
        let json_string: String = serde_json::to_string(&json_value).unwrap();

        let t_item : LuaTable = lua.create_table()?;
        t_item.set("user_data", json_string)?;
        t_item.set("word", "")?;
        t_item.set("menu", "")?;
        t_item.set("equal", 0)?;
        t_item.set("dup", 1)?;
        t_item.set("info", "")?;
        t_item.set("kind", "")?;
        t_item.set("abbr", "")?;
        t_item.set("kind_number", 0)?;
        t_item.set("plugin_name", plugin_name.clone())?;
        t_item.set("user_data_json", r_user_data)?;

        for pair in item.pairs::<Value, Value>() {
            let (key, value) = pair?;
            t_item.set(key, value)?;
        }
        l_menu_list.push(t_item)?;
    }
    Ok(l_menu_list)
}

#[mlua::lua_module(skip_memory_check)]
fn easycomplete_rust_speed(lua: &Lua) -> LuaResult<LuaTable> {
    let exports = lua.create_table()?;

    // 测试用
    exports.set("hello", lua.create_function(hello)?)?;
    exports.set("return_table", lua.create_function(return_table)?)?;
    exports.set("return_kv_table", lua.create_function(return_kv_table)?)?;
    exports.set("parse_table", lua.create_function(parse_table)?)?;
    exports.set("get_global_vars", lua.create_function(get_global_vars)?)?;
    exports.set("get_first_complete_hit", lua.create_function(get_first_complete_hit)?)?;
    exports.set("badboy_vim", lua.create_function(badboy_vim)?)?;

    // rust 重写的 lua 函数
    exports.set("replacement", lua.create_function(replacement)?)?;
    exports.set("parse_abbr", lua.create_function(parse_abbr)?)?;
    exports.set("complete_menu_filter", lua.create_function(complete_menu_filter)?)?;
    exports.set("trim_array_to_length", lua.create_function(trim_array_to_length)?)?;
    exports.set("matchfuzzypos", lua.create_function(matchfuzzypos)?)?;
    exports.set("complete_menu_fuzzy_filter", lua.create_function(complete_menu_fuzzy_filter)?)?;
    exports.set("final_normalize_menulist", lua.create_function(final_normalize_menulist)?)?;

    Ok(exports)
}

