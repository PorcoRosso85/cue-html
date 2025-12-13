package schema

// #Fragment は再利用可能なHTMLコンテンツの断片を定義
#Fragment: {
	// フラグメントの一意識別子
	id: string

	// セクションのタイトル（見出しテキスト）
	title: string

	// HTML形式の本文コンテンツ
	bodyHtml: string
}

// #Section はページ内のセクション構造を定義
#Section: {
	// セクションの一意識別子
	id: string

	// 見出しレベル (1=h1, 2=h2, 3=h3)
	level: int & >=1 & <=3

	// 参照するFragmentのID
	fragmentId: string

	// 親セクションのID（ネスト構造用、オプショナル）
	parentId?: string
}

// #Page は完全なページ定義を表す
#Page: {
	// ページの一意識別子
	id: string

	// ページの種類（docs/article/lp）
	kind: "docs" | "article" | "lp"

	// URLパス（例: "/docs/intro"）
	path: string & =~"^/"

	// ページを構成するセクションのリスト
	sections: [...#Section]

	// canonical URL（SEO用、オプショナル）
	canonical?: string
}
