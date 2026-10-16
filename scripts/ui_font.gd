## 화면 글꼴: 데스크톱은 시스템 글꼴, 웹은 시스템 글꼴이 없어 함께 넣은 Noto Sans KR (SIL OFL, assets/fonts)
const BUNDLED := "res://assets/fonts/NotoSansKR-VF.ttf"


static func make(names: PackedStringArray) -> Font:
	if OS.has_feature("web"):
		var v := FontVariation.new()
		v.base_font = load(BUNDLED)
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): 500}
		return v
	var f := SystemFont.new()
	f.font_names = names
	return f
