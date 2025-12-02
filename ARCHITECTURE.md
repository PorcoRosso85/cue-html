# CUE-HTML Architecture - 責務と契約 v2

> **注意**: このドキュメントは実装フェーズのアーキテクチャ定義です。実装完了後は削除予定です。

## v1→v2 変更点
- ❌ `schema/htmx.cue` 削除（htmx CDN は render/common.cue に直接埋め込み）
- ❌ `render/commands.cue` 削除（Makefile に統合）
- ❌ `scripts/print-html.sh` 削除（Go版のみに集中）

> **注意**: このドキュメントは実装フェーズのアーキテクチャ定義です。実装完了後は削除予定です。

## v3 の方針（根本的な見直し）

### このrepoのゴール
**「CUEで `renderedPages: [{ path, html }]` を出すこと」**

それ以外（ファイル書き出し、ビルドシステム、CI等）は設計範囲外。

### v2からの根本的変更
- ❌ **Build Layer削除** - Makefile等はこのrepoの責務ではない
- ❌ **Printer Layer削除** - JSONを書き出すだけのコードは設計対象外
- ❌ **Export Layer削除** - Render Layerに統合
- ✅ **レイヤーを3つに単純化**: Schema, Content, Render
- ✅ **render/ を1ファイルに統合**: render/html.cue
- ✅ **content/ も2ファイルに統合**: fragments.cue, pages.cue

---

## 1. レイヤー構造（3層のみ）

```
┌─────────────────────────────────────────────────────────────┐
│                   Schema Layer (型・制約)                     │
│  schema/model.cue, schema/validation.cue                    │
│  [責務] #Fragment/#Section/#Page 型定義と制約ルール           │
└─────────────────────────────────────────────────────────────┘
                            ↓ 使用
┌─────────────────────────────────────────────────────────────┐
│                   Render Layer (変換)                        │
│  render/print-html.cue, render/layout.cue, render/export.cue│
│  [責務] Fragment/Section/Page → HTML文字列への変換          │
└─────────────────────────────────────────────────────────────┘
                            ↓ 変換
┌─────────────────────────────────────────────────────────────┐
│              Export Layer (JSON生成)                         │
│  render/export.cue                                          │
│  [責務] renderedPages 構造の定義、export可能な形式に整形     │
└─────────────────────────────────────────────────────────────┘
                            ↓ exported by
┌─────────────────────────────────────────────────────────────┐
│                  Build Layer (実行)                          │
│  Makefile                                                   │
│  [責務] cue export 実行、プリンタ呼び出し、クリーンアップ     │
└─────────────────────────────────────────────────────────────┘
                            ↓ calls
┌─────────────────────────────────────────────────────────────┐
│                  Printer Layer (出力)                        │
│  cmd/html-printer/main.go                                   │
│  [責務] JSON → ファイルシステムへの書き出しのみ               │
└─────────────────────────────────────────────────────────────┘
                            ↓ writes
┌─────────────────────────────────────────────────────────────┐
│                     Output (成果物)                          │
│  out/**/*.html                                              │
│  [成果物] 完全なcanonical HTML（SEO対応、htmx対応）         │
└─────────────────────────────────────────────────────────────┘
                            ↓
                  (このrepoのゴール)
            `cue export -e render.renderedPages`
```

### v2から削除したレイヤー
- ❌ **Export Layer** - Render Layerに統合（renderedPages は render/html.cue で定義）
- ❌ **Build Layer** - このrepoの責務外（利用者が Makefile 等を別途用意）
- ❌ **Printer Layer** - このrepoの責務外（サンプルスクリプトとして scripts/ に配置）

---

## 2. 各ファイルの詳細責務

### 2.1 Schema Layer

#### `schema/model.cue`

**責務**:
- `#Fragment` 型の定義
  - `id: string` - 一意識別子
  - `title: string` - 見出しテキスト
  - `bodyHtml: string` - 正規化されたHTML本文（h*タグなし）
- `#Section` 型の定義
  - `id: string` - セクション識別子
  - `level: 1 | 2 | 3` - 見出しレベル
  - `parentId?: string` - 親セクションへの参照（任意）
  - `fragmentId: string` - 使用するフラグメントのID
- `#Page` 型の定義
  - `id: string` - ページ識別子
  - `kind: "docs" | "article" | "lp"` - ページ種別
  - `path: string` - URL パス（例: `/docs/intro`）
  - `sections: [...#Section]` - セクションリスト
  - `canonical?: string` - canonical URL（任意）
  - `indexPolicy?: "index" | "noindex"` - SEO indexing ポリシー

**契約**:
- 型定義の破壊的変更は禁止（後方互換性を保つ）
- 新フィールド追加は任意（`?`）で行う

#### `schema/validation.cue`

**責務**:
- `#Page.path` の重複禁止チェック
- `#Section.fragmentId` が `#Fragment.id` に存在することの検証
- 1ページ内の `level=1` が最大1つであることの検証
- `level` の飛び級（1→3）禁止
- `#Section.parentId` が存在する場合、既存セクションを指すことの検証

**契約**:
- `cue vet ./...` で全検証が実行可能
- エラーメッセージは具体的（どのページ・セクションが違反しているか明示）

**削除**: `schema/htmx.cue` は v1 では作成しません
- htmx CDN の `<script>` タグは `render/common.cue` に直接埋め込み
- hx-get 等の動的属性は Phase 7（将来）で実装時に schema/htmx.cue を追加

---

### 2.2 Render Layer

#### `render/common.cue`

**責務**:
- `<head>` タグの生成
  - `<meta charset="UTF-8">`
  - `<meta name="viewport" ...>`
  - **htmx CDN script タグ**（v1では直接埋め込み）
    - 例: `<script src="https://cdn.jsdelivr.net/npm/htmx.org@2.0.8/dist/htmx.min.js" integrity="..." crossorigin="anonymous"></script>`
  - canonical link（ページごとに動的）
- `<footer>` タグの生成
- 共通 CSS（インライン or 外部リンク）

**契約**:
- `headHtml(page: #Page) -> string` 関数を提供
- `footerHtml() -> string` 関数を提供
- htmx バージョンアップ時はこのファイルの `<script>` タグを更新

#### `render/layout.cue`

**責務**:
- `kind` による HTML構造の分岐
  - `"docs"` → サイドバー付きレイアウト
  - `"article"` → 記事レイアウト（breadcrumb等）
  - `"lp"` → LP用ヘッダー・CTA
- レイアウトごとの wrapper HTML 生成

**契約**:
- `layoutHtml(page: #Page, contentHtml: string) -> string` 関数を提供
- contentHtml（本文）を受け取り、レイアウトでラップして返す

#### `render/print-html.cue`

**責務**:
- **Section → HTML 変換**
  - `level` に応じて `<h1>` / `<h2>` / `<h3>` を決定
  - `fragmentId` から `#Fragment` を引いて `title` / `bodyHtml` を取得
  - `<section id="..."><h*>title</h*>bodyHtml</section>` を生成
- **Page → sectionsHtml 配列生成**
  - `page.sections` をループして各 section の HTML を生成
  - `sectionsHtml: [...string]` に格納
- **renderedPages 生成**
  - 全ページをループ
  - `{ path: page.path, html: fullPageHtml }` の配列を出力
  - `fullPageHtml = layoutHtml(page, join(sectionsHtml, "\n"))`

**契約**:
- `render.renderedPages` という名前で export される
- 構造: `[{ path: string, html: string }, ...]`
- `html` は `<!DOCTYPE html>` から始まる完全なHTML

#### `render/export.cue`

**責務**:
- `renderedPages` 構造の定義
  - `[{ path: string, html: string }, ...]` の形式
- export 可能な形に整形
  - `cue export -e render.renderedPages` で取得可能にする

**契約**:
- `render.renderedPages` という名前で export される
- この段階ではファイル出力はしない（JSON構造の定義のみ）

---

### 2.3 Build Layer

#### `Makefile`

**責務**:
- `ssg` ターゲットの定義
- 実行フロー:
  1. `cue export -e render.renderedPages > tmp/renderedPages.json`
  2. `go run ./cmd/html-printer tmp/renderedPages.json ./out`
  3. `rm tmp/renderedPages.json`（クリーンアップ）

**契約**:
- `make ssg` で HTML 生成が完結
- CUE と Go の橋渡し役
- エラーハンドリング（cue export 失敗時は printer を呼ばない）

---

### 2.4 Content Layer

#### `content/fragments/common.cue`

**責務**:
- docs/articles/LP 共通で使える汎用フラグメント定義
- 例:
  - `frag-intro`: サービス紹介
  - `frag-cta`: CTA文言
  - `frag-privacy`: プライバシーポリシー要約

**構造**:
```cue
fragments: {
    "frag-intro": {
        id: "frag-intro"
        title: "はじめに"
        bodyHtml: "<p>...</p>"
    }
    // ...
}
```

**契約**:
- 各フラグメントは `schema/model.cue` の `#Fragment` 型に準拠
- `bodyHtml` は正規化されたHTML（h*タグなし、well-formed）

#### `content/pages.cue`

**責務**:
- `/docs/**`, `/articles/**`, `/solo/**` のページ定義
- 各ページは `#Page` 型に準拠
- `sections` で使用するフラグメントを参照

**構造**:
```cue
pages: [
    {
        id: "docs-intro"
        kind: "docs"
        path: "/docs/intro"
        sections: [
            { id: "s1", level: 1, fragmentId: "frag-intro" },
            // ...
        ]
    },
    // ...
]
```

**契約**:
- 全ページが `schema/validation.cue` の制約を満たす
- `fragmentId` は `content/fragments.cue` で定義されたものを参照

---

### 2.5 Printer Layer

#### `cmd/html-printer/main.go`

**責務**:
- **JSON読み込み**
  - `tmp/renderedPages.json` を読む
  - `[]struct { Path string, Html string }` にデコード
- **ファイル書き出し**
  - `path` → `outDir + path + "/index.html"` に変換
  - ディレクトリが存在しなければ作成（`os.MkdirAll`）
  - `html` をそのまま書き込む
- **エラーハンドリング**
  - JSON parse エラー → exit 1
  - ファイル書き込みエラー → exit 1

**契約**:
- コマンドライン引数: `html-printer <jsonPath> <outDir>`
- 終了コード: 0（成功）, 1（失敗）
- **テンプレートロジックは一切持たない**（単なる書き出し器）

**削除**: `scripts/print-html.sh` は v1 では実装しません
- Go版のみに集中（将来の拡張性を考慮）
- 必要になったら後で追加可能

**1. headHtml(page: #Page) -> string**

### 2.6 Test Layer

#### `tests/validation_test.cue`

**責務**:
- **異常系テスト**: わざと制約違反のデータを作成
  - path重複エラー
  - fragmentId不在エラー
  - level飛び級エラー
  - 複数H1エラー
- `cue vet` を実行して「エラーが出ること」を確認

**役割の明確化**:
- 正常系: `schema/validation.cue` の制約定義
- 異常系: `tests/validation_test.cue` でエラー発火テスト

**2. sectionHtml(section: #Section, fragment: #Fragment) -> string**

- Section → HTML 変換
- 出力例: `<section id="s1"><h1>タイトル</h1><p>本文...</p></section>`
- `level` に応じて `<h1>` / `<h2>` / `<h3>` を決定
- `fragment.title` と `fragment.bodyHtml` を組み合わせる

**3. pageHtml(page: #Page) -> string**

- Page → 完全なHTML生成
- 処理フロー:
  1. 全 `sections` をループして `sectionHtml` で変換
  2. sectionsHtml を `\n` で join
  3. `kind` による分岐（docs/article/lp でレイアウト差を実装）
  4. `<html><head>...</head><body>...</body></html>` で包む

**4. renderedPages: [{ path: string, html: string }, ...]**

**責務**:
- 全HTMLファイルに htmx CDN が含まれるかチェック
- 手順:
  1. `find out/ -name "*.html"` で全HTML取得
  2. 各ファイルで `grep -q "htmx.org"`（**バージョン非依存**）
  3. 含まれないファイルがあれば exit 1

**バージョン非依存の理由**:
- htmx のバージョンアップ時にテストが壊れないようにする
- `@2.0.8` のようなバージョン番号は見ない

**契約**:
- `renderedPages` の各要素は以下を満たす:
  - `path` が `/docs/**`, `/articles/**`, `/solo/**` のいずれかに一致
  - `html` が `<!DOCTYPE html>` から始まる
  - `<head>` 内に `htmx.org` を含む `<script>` タグがある
- htmx バージョンアップ時はこのファイルの `<script>` タグを更新

---

## 3. データフロー図

```
[content/fragments.cue]
        ↓ defines
[Fragment値集合]
        ↓
[content/pages.cue] ←─── [schema/model.cue]
        ↓ uses          (型定義)
[Page値集合]
        ↓
[render/html.cue]
        ↓ references Fragments
        ↓ generates HTML strings
[renderedPages]
        ↓
[cue export -e render.renderedPages]
        ↓
[JSON: [{ path, html }]]
        ↓
   (このrepoのゴール)
```

**このrepo外のフロー**（利用者の責任範囲）:
```
[JSON]
  ↓
[サンプルスクリプト or 利用者独自ツール]
  ↓
[out/**/*.html]
  ↓
[デプロイ: R2, S3, etc.]
```

---

## 4. 依存関係マトリックス

| Layer | 依存先 | 依存理由 |
|-------|--------|---------|
| Content | Schema | 型定義に準拠 |
| Render | Schema, Content | 型定義を使い、コンテンツ値を変換 |
| Export | Render | renderedPages 構造を定義 |
| Build (Makefile) | Export, Printer | cue export を実行し、Printer を呼び出す |
| Printer | - | JSON を受け取るのみ（他レイヤーに依存しない） |
| Test | Schema, Render, Printer | バリデーション・出力検証 |

**循環依存禁止**: Schema → Content → Render → Export → Build → Printer の一方向のみ

**v1→v2 変更点**:
- Command Layer（render/commands.cue）を Build Layer（Makefile）に置き換え
- Printer は JSON のみを受け取る純粋な出力器（他レイヤーへの依存なし）

---

## 5. サンプルスクリプトについて（オプション）

### 位置づけ
**このrepoの本質的な責務ではない**が、利用者の便宜のためにサンプルとして配置可能。

### `scripts/print-html.sh` の仕様

**責務**:
- 標準入力 または JSONファイルから `renderedPages` を読む
- 各要素について:
  - `path` → `out/` 以下のディレクトリに変換（`/docs/intro` → `out/docs/intro/index.html`）
  - `html` をそのまま書き出す
- **テンプレート処理・条件分岐・レイアウト変更は一切しない**

**制約**:
- **500行未満厳守**（IOラッパーとして最小限）
- CUEが決めた値を「そのまま吐くだけ」
- このスクリプトに機能を追加していくことは禁止（別ツールを作るべき）

**使用例**:
```bash
# 標準入力から読む
cue export -e render.renderedPages | ./scripts/print-html.sh

# ファイルから読む
cue export -e render.renderedPages > pages.json
./scripts/print-html.sh < pages.json
```

### 5.2 htmx 動的差し替え機能追加（Phase 7）

**変更箇所**:
1. `schema/htmx.cue`: **新規作成** - `#Section` に `hxGet?`, `hxTarget?` フィールド追加
2. `schema/model.cue`: `#Section` を `schema/htmx.cue` の型を使うように変更
3. `render/print-html.cue`: `hxGet` が存在する場合 `hx-get` 属性を付与
4. `tests/htmx_check.sh`: `hx-get` 属性の検証追加

**変更不要**:
- Printer（HTML文字列は変わるが、JSON構造は同じ）
- Makefile（ビルドフローは変わらない）

**リスク**: `bodyHtml` に `<script>` タグが混入

**対策**:
- `bodyHtml` は **信頼できるコンテンツのみ** とする（UGC禁止）
- 将来UGCを扱う場合は、別レイヤーでサニタイズ
- （オプション）CUE のバリデーションで `<script>` タグ検出

### 6.2 Path Traversal（サンプルスクリプトの場合）

**リスク**: `path: "../../etc/passwd"` のような悪意ある値

**対策**（サンプルスクリプト実装時）:
- path を正規化（不正な `..` を除去）
- `outDir` の外に書き込まないことを保証
- （オプション）CUE のバリデーションで `path` の形式チェック（`/[a-z0-9/-]+`）

---

## 7. パフォーマンス考慮事項

### 7.1 CUE の評価速度

**想定**: 100ページ程度なら問題なし（< 1秒）

**懸念**: 1000+ ページでは遅延の可能性

**採用案**: Go版のみ実装

### 7.2 HTML文字列サイズ

**想定**: 1ページ数十KB程度なら問題なし

**結論（v2）**: Go版のみ実装。sh版は v1 では作成しない（必要になったら後で追加）。

**対策**:
- `bodyHtml` には大きなデータを入れない（画像はURLで参照）
- 必要に応じて minify を別ツールで実施（このrepoの範囲外）

---

## 8. 拡張ポイント（将来）

### 8.1 新しいページ種別追加（例: "landing-page-v2"）

**変更箇所**:
1. `schema/model.cue`: `kind` に `"landing-page-v2"` 追加
2. `render/html.cue`: `pageHtml` 内で kind による分岐を追加
3. `content/pages.cue`: 新規ページ定義追加

**変更不要**:
- サンプルスクリプト（JSON構造は同じ）

### 8.2 htmx 動的差し替え機能追加（Phase 7）

**変更箇所**:
1. `schema/model.cue`: `#Section` に `hxGet?`, `hxTarget?` フィールド追加
2. `render/html.cue`: `sectionHtml` で `hxGet` が存在する場合 `hx-get` 属性を付与

**変更不要**:
- サンプルスクリプト（HTML文字列は変わるが、JSON構造は同じ）

---

## 9. トレードオフの明示

### 9.1 CUE vs Go の責務分担

**採用案**: CUE = 型+データ+HTML生成、外部 = 保存のみ

**トレードオフ**:
- ✅ メリット: 型とテンプレートが密結合、バリデーションが強力
- ✅ メリット: ロジックが一元化（CUEを見ればすべて分かる）
- ❌ デメリット: CUE の文字列操作が冗長になる可能性
- ❌ デメリット: 大量ページ（1000+）では CUE が遅い可能性

**結論**: 当面は CUE に寄せる。パフォーマンス問題が出たら Go 移行を検討。

### 9.2 render/ を1ファイルに統合

**採用案**: render/html.cue 1ファイルのみ

**トレードオフ**:
- ✅ メリット: シンプル、見通しが良い
- ✅ メリット: 依存関係が明確
- ❌ デメリット: ファイルが大きくなる可能性（数百行）

**結論**: v1では1ファイルで進める。1000行を超えたら分割検討。

### 9.3 サンプルスクリプトの提供

**採用案**: scripts/print-html.sh をサンプルとして配置（オプション）

**トレードオフ**:
- ✅ メリット: 利用者がすぐに試せる
- ❌ デメリット: サンプルが肥大化するリスク

**結論**: 500行未満厳守。それを超える場合は別repoへ分離。

---

この v3 アーキテクチャは、**「CUEでpath+htmlを出すこと」に徹底的に集中**した設計です。
それ以外の複雑さ（Build/Printer/CI等）は全て範囲外とし、利用者が必要に応じて追加する前提です。
