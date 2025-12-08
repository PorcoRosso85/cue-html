package schema

import "list"

// fragments はフラグメント定義のマップ
// キーは Fragment.id と一致しなければならない
fragments: [ID=string]: #Fragment & {
	id: ID
}

// pages はページ定義のリスト
pages: [...#Page]

// === バリデーションルール ===

// 1. path の重複禁止
// すべてのページのpathは一意でなければならない
let allPaths = [ for p in pages {p.path}]
_pathUnique: len(allPaths) == len({for p in allPaths {(p): true}})
_pathUnique: true

// 2. fragmentId 参照整合性
// すべてのsection.fragmentIdは有効なfragments[id]を参照しなければならない
for p in pages for s in p.sections {
	_fragRefValid: fragments[s.fragmentId] != _|_
	_fragRefValid: true
}

// 3. 1ページ1つのH1制約
// 各ページはlevel=1のセクションを正確に1つ持たなければならない
for p in pages {
	let h1Count = len([ for s in p.sections if s.level == 1 {s}])
	_h1Count: h1Count == 1
	_h1Count: true
}

// 4. level の飛び級禁止
// セクションのlevelは連続していなければならない（1→3は不可）
for p in pages {
	let levels = [ for s in p.sections {s.level}]
	let sortedLevels = list.Sort(levels, list.Ascending)

	// 最小レベルは1でなければならない
	_minLevel: sortedLevels[0] == 1
	_minLevel: true

	// 連続する要素の差は最大1
	for i, level in sortedLevels if i > 0 {
		let prevLevel = sortedLevels[i-1]
		_levelContinuity: level - prevLevel <= 1
		_levelContinuity: true
	}
}

// 5. parentId の整合性チェック
// parentId が指定されている場合、同一ページ内の既存セクションIDを指す必要がある
for p in pages for s in p.sections if s.parentId != _|_ {
	let sectionIds = [ for sec in p.sections {sec.id}]
	_parentIdValid: list.Contains(sectionIds, s.parentId)
	_parentIdValid: true
}
