package schema

// Sample fragments for testing
fragments: {
	"intro": {
		id:       "intro"
		title:    "はじめに"
		bodyHtml: "<p>CUE-HTMLへようこそ。このプロジェクトはCUE言語を使った型安全なHTML生成エンジンです。</p>"
	}

	"features": {
		id:    "features"
		title: "主な特徴"
		bodyHtml: """
			<ul>
			  <li>型安全: CUEの強力な型システムでHTMLの構造を保証</li>
			  <li>再利用性: Fragment/Section/Pageの3層モデル</li>
			  <li>シンプル: CUEだけで完結</li>
			</ul>
			"""
	}

	"getting-started": {
		id:    "getting-started"
		title: "使い方"
		bodyHtml: """
			<p>基本的な使い方は非常にシンプルです：</p>
			<pre><code>cue export -e renderedPages ./schema</code></pre>
			<p>これでJSON形式のページデータが出力されます。</p>
			"""
	}

	"article-intro": {
		id:       "article-intro"
		title:    "記事タイトル"
		bodyHtml: "<p>これはサンプル記事のイントロダクションです。</p>"
	}

	"article-body": {
		id:    "article-body"
		title: "本文"
		bodyHtml: """
			<p>記事の本文がここに入ります。</p>
			<p>複数の段落を含めることができます。</p>
			"""
	}

	"lp-hero": {
		id:       "lp-hero"
		title:    "CUE-HTMLで始める型安全なHTML生成"
		bodyHtml: "<p>最も簡単で、最も安全なHTML生成方法</p>"
	}

	"lp-cta": {
		id:    "lp-cta"
		title: "今すぐ始める"
		bodyHtml: """
			<p>GitHubでソースコードを確認：</p>
			<pre><code>git clone https://github.com/porcorosso85/cue-html.git</code></pre>
			"""
	}
}
