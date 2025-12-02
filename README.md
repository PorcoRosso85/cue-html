# CUE-HTML: CUE-based HTML Generation

**このrepoのゴール**: `cue export -e render.renderedPages` で `[{ path, html }]` のJSONを出力すること。

それ以上でも、それ以下でもない。

---

## 概要

CUE言語を使ってHTMLを生成する、型安全なHTML生成エンジンです。

### 特徴

- **型安全**: CUEの強力な型システムと制約で、HTMLの構造を保証
- **再利用性**: Fragment/Section/Page の3層モデルで、コンテンツの再利用が容易
- **シンプル**: CUEだけで完結。外部のテンプレートエンジンやビルドツールは不要

### このrepoの範囲

✅ **範囲内**: CUEで `renderedPages: [{ path, html }]` を出力すること

❌ **範囲外**:
- ファイル書き出し（利用者が独自ツールで実装）
- ビルドシステム（Makefile等は利用者が別途用意）
- CI/CD設定
- デプロイ

---

## 環境構築

### 必要なもの

- [CUE](https://cuelang.org/) v0.9.0+

### インストール

CUEをインストールしてください：

```bash
# macOS (Homebrew)
brew install cue

# Linux (go install)
go install cuelang.org/go/cmd/cue@latest

# その他の方法は公式サイトを参照
# https://cuelang.org/docs/install/
```

### リポジトリのクローン

```bash
git clone https://github.com/PorcoRosso85/cue-html.git
cd cue-html
```

---

## 使い方

### 1. renderedPages をJSONで出力

このrepoの主要なAPIです：

```bash
cue export -e render.renderedPages
```

出力例：

```json
[
  {
    "path": "/docs/intro",
    "html": "<!DOCTYPE html><html><head>...</head><body>...</body></html>"
  },
  {
    "path": "/articles/example",
    "html": "<!DOCTYPE html>..."
  }
]
```

### 2. （オプション）ファイルに書き出す

サンプルスクリプトを使う場合：

```bash
# scripts/print-html.sh を作成後
cue export -e render.renderedPages | ./scripts/print-html.sh
```

または、独自ツールで実装：

```bash
# Go
cue export -e render.renderedPages | go run your-printer.go

# Python
cue export -e render.renderedPages | python your-printer.py

# jq + bash
cue export -e render.renderedPages | jq -r '.[] | "\(.path) \(.html)"' | while read path html; do
  mkdir -p "out$(dirname $path)"
  echo "$html" > "out$path/index.html"
done
```

---

## プロジェクト構造

```
cue-html/
├── cue.mod/module.cue       # CUEモジュール定義
├── schema/                  # 型定義と制約
│   ├── model.cue            # #Fragment/#Section/#Page
│   └── validation.cue       # 参照整合性・H1制約等
├── content/                 # 実コンテンツ
│   ├── fragments.cue        # 再利用フラグメント
│   └── pages.cue            # ページ定義
├── render/                  # HTML生成
│   └── html.cue             # headHtml/sectionHtml/pageHtml/renderedPages
└── scripts/                 # （オプション）サンプルスクリプト
    └── print-html.sh        # JSON→ファイル書き出し
```

### 3つのレイヤー

1. **Schema Layer** (`schema/`)
   - 型定義（#Fragment, #Section, #Page）
   - 制約ルール（path重複禁止、H1は1つまで等）

2. **Content Layer** (`content/`)
   - 実際のコンテンツ値
   - Fragment（再利用可能なHTML断片）
   - Page（Fragment を組み立てたページ定義）

3. **Render Layer** (`render/`)
   - HTML文字列の生成ロジック
   - `renderedPages` の出力

---

## バリデーション

CUEの強力な制約機能で、以下をチェック：

```bash
cue vet ./...
```

- path の重複禁止
- fragmentId の参照整合性
- 1ページ1つの H1
- level の飛び級禁止（1→3は不可）

---

## 開発ワークフロー

### 1. Fragment を追加

`content/fragments.cue` にHTMLコンテンツを追加：

```cue
fragments: {
    "my-fragment": {
        id: "my-fragment"
        title: "新しいセクション"
        bodyHtml: "<p>本文...</p>"
    }
}
```

### 2. Page を定義

`content/pages.cue` でページ構造を定義：

```cue
pages: [
    {
        id: "my-page"
        kind: "docs"
        path: "/docs/my-page"
        sections: [
            { id: "s1", level: 1, fragmentId: "my-fragment" }
        ]
    }
]
```

### 3. 検証

```bash
cue vet ./...
```

### 4. 出力

```bash
cue export -e render.renderedPages
```

---

## htmx サポート

すべてのページに htmx CDN が自動的に含まれます：

```html
<script src="https://cdn.jsdelivr.net/npm/htmx.org@2.0.8/dist/htmx.min.js"
        integrity="..." crossorigin="anonymous"></script>
```

動的な `hx-get` 属性等は将来のバージョンで対応予定です。

---

## 将来の拡張

以下は現在の範囲外ですが、将来的に追加可能：

- hx-get 等の動的属性サポート
- sitemap.xml / robots.txt 生成
- マルチサイト対応
- 差分ビルド
- HTML minify

---

## ライセンス

MIT

---

## 貢献

Issue や Pull Request を歓迎します。

このrepoは「CUEで `renderedPages` を出すこと」に集中しています。
ファイル書き出しやビルドツールの機能追加は、別repoでの実装を推奨します。
