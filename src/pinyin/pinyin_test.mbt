// Pinyin lookup tests (pinyin-suggest task 1.1).

///|
test "single character lookups" {
  assert_eq(pinyin_of('春'), Some("chun"))
  assert_eq(pinyin_of('节'), Some("jie"))
  assert_eq(pinyin_of('女'), Some("nv"))
  assert_eq(pinyin_of('绿'), Some("lv"))
  assert_eq(pinyin_of('中'), Some("zhong"))
  assert_eq(pinyin_of('秋'), Some("qiu"))
  // not in table
  assert_eq(pinyin_of('龘'), None)
  assert_eq(pinyin_of('a'), None)
}

///|
test "phrase pinyin concatenates and skips unknown chars" {
  assert_eq(phrase_pinyin("春节"), "chunjie")
  assert_eq(phrase_pinyin("中秋节"), "zhongqiujie")
  assert_eq(phrase_pinyin("端午节"), "duanwujie")
  // spaces/latin/rare chars are skipped
  assert_eq(phrase_pinyin("moonbit 语言"), "yuyan")
  assert_eq(phrase_pinyin("!!龘!!"), "")
  assert_eq(phrase_pinyin(""), "")
}

///|
test "phrase initials" {
  assert_eq(phrase_initials("春节"), "cj")
  assert_eq(phrase_initials("中秋节"), "zqj")
  assert_eq(phrase_initials("农历 节气"), "nljq")
  assert_eq(phrase_initials("moonbit 语言"), "yy")
}

///|
test "table size is in the expected range" {
  // the packed data must stay a healthy common-character set
  let mut n = 0
  for
    _, ch in phrase_pinyin(
      "一乙二十丁厂七人入八九几儿了力乃刀又三于干亏士工土才寸下大丈与万上小口巾山千乞川亿个勺久夕凡及广亡门义之尸弓己已子卫也女飞习乡马丰王井开夫天无元专云扎艺木五支厅不太犬区历尤友匹车巨牙屯比互切瓦止少日中冈贝内水见午牛手毛气升长仁什片仆化仇币仍仅斤爪反介父从今凶分乏公仓月氏勿欠风丹匀乌凤勾文六方火为斗忆订计户认心尺引丑巴孔队办以允予劝双书幻玉刊示末未击打巧正扑扒功扔去甘世古节本术可丙左厉右石布龙平灭轧东卡北占业旧帅归且旦目叶甲申叮电号田由史只央兄叼叫另叨叹四生失禾丘付仗代仙们仪白仔他斥瓜乎丛令用甩印乐句匆册犯外处冬鸟务包饥主市立闪兰半汁汇头汉宁穴它讨写让礼训必议讯记永司尼民出辽奶奴加召皮边发孕圣对台矛纠母幼丝",
    ) {
    ignore(ch)
    n = n + 1
  }
  assert_true(n > 300)
}
