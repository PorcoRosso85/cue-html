# CUE-HTML Generation Project - 作業計画書 v3

> **注意**: このドキュメントは実装フェーズの計画書です。実装完了後は削除予定です。

## v3 の方針（根本的な見直し）

### このrepoのゴール
**「`cue export -e render.renderedPages` でpath+htmlのJSONを正しく出すこと」**

それ以上でも、それ以下でもない。

### v2からの根本的変更
- ❌ **Makefile/Build Layerをアーキテクチャから削除** - このrepoの責務ではない
- ❌ **Printer Layerをアーキテクチャから削除** - 「JSONを受け取って書き出すだけ」はこのrepoの設計対象外
- ❌ **Phase 7-9の詳細計画を削除** - v1に集中する
- ✅ **レイヤーを3つに単純化**: schema, content, render
- ✅ **render/ 配下を1ファイルに統合**: render/html.cue
- ✅ **薄スクリプトはサンプル扱い**: scripts/ はオプション

### 「生成」の定義（明確化）
- **CUEがやること**: path + html を決める（これが「生成」）
- **CUE以外**: 決まった値を保存・運搬するだけ（このrepoの設計対象外）

---

## 1. プロジェクト構造（Tree with 責務）

```
cue-html/
├── cue.mod/
│   └── module.cue               # [責務] CUEモジュール名・バージョン定義
│
├── schema/                      # [責務] 型定義とバリデーション
│   ├── model.cue                # [責務] #Fragment/#Section/#Page 型定義
│   └── validation.cue           # [責務] 参照整合性・path重複・H1/level制約
│
├── content/                     # [責務] 実コンテンツ定義（値）
│   ├── fragments.cue            # [責務] 全フラグメント定義（docs/articles/lp共通）
│   └── pages.cue                # [責務] /docs/**, /articles/**, /solo/** ページ定義
│
├── render/                      # [責務] HTML生成（CUEのみ）
│   └── html.cue                 # [責務] headHtml/sectionHtml/pageHtml/renderedPages
│
├── scripts/                     # [オプション] サンプルスクリプト（このrepoの本質的責務外）
│   └── print-html.sh            # [サンプル] JSON→ファイル書き出し（500行以下厳守）
│
└── README.md                    # [責務] 使い方（cue export の例、サンプルスクリプトの説明）
```

### v2から削除したもの
- ❌ `render/common.cue`, `render/layout.cue`, `render/export.cue` → `render/html.cue` に統合
- ❌ `cmd/html-printer/` → サンプルは `scripts/print-html.sh` のみ
- ❌ `Makefile` → README に使用例として記載するだけ
- ❌ `tests/` → Phase 4（テスト）で必要最小限のみ追加検討
- ❌ `.github/workflows/` → CI設定はこのrepoの範囲外（使いたい人が別レイヤーで設定）

---

## 2. CUE インターフェース（契約）

### 2.1 `schema/model.cue` - 型定義

```cue
#Fragment: {
    id:       string
    title:    string
    bodyHtml: string  // h*タグなし、正規化されたHTML
}

#Section: {
    id:         string
    level:      1 | 2 | 3
    parentId?:  string
    fragmentId: string
}

#Page: {
    id:           string
    kind:         "docs" | "article" | "lp"
    path:         string  // 例: /docs/intro
    sections:     [...#Section]
    canonical?:   string
    indexPolicy?: "index" | "noindex"
}
```

### 2.2 `schema/validation.cue` - 制約

- 1ページ1 H1（level == 1 は1つだけ）
- level 飛び級禁止（1→3はエラー）
- fragmentId が必ず既知の Fragment を指す
- path が一意
- parentId が必ず同一ページ内の既存 Section を指す

### 2.3 `render/html.cue` - HTML生成

**提供する関数**:
```cue
// <head> タグ生成（htmx CDN含む）
headHtml: (page: #Page) -> string

// Section → HTML変換
sectionHtml: (section: #Section, fragment: #Fragment) -> string

// Page → 完全なHTML生成
pageHtml: (page: #Page) -> string

// 最終出力
renderedPages: [{ path: string, html: string }, ...]
```

**責務**:
- `headHtml`: `<meta charset>`, `<meta viewport>`, htmx CDN `<script>`、canonical
- `sectionHtml`: `<section id="..."><h{level}>title</h{level}>bodyHtml</section>`
- `pageHtml`: sectionsHtml を `\n` で join して `<html>...</html>` で包む
- `renderedPages`: 全ページについて `{ path: page.path, html: pageHtml(page) }` を生成

---

## 3. DoD（Definition of Done）

### 3.1 CUE の完成基準（必須）

- [ ] `cue vet ./schema ./content ./render` がエラーなく通る
- [ ] `cue export -e render.renderedPages` が成功する
- [ ] renderedPages の各要素が以下を満たす：
  - [ ] `path` が `/docs/**`, `/articles/**`, `/solo/**` のいずれかに一致
  - [ ] `html` が `<!DOCTYPE html>` から始まる
  - [ ] `<head>` 内に `htmx.org` を含む `<script>` タグがある

### 3.2 HTML品質の基準（手動確認）

- [ ] 代表3ページ（docs/article/lp 各1つ）について：
  - [ ] ブラウザで開いて表示崩れがない
  - [ ] H1 が1つだけ存在し、H2/H3 が想定どおりの階層
- [ ] （オプション）W3C Validator で手動チェック（エラーなし推奨）

### 3.3 サンプルスクリプトの基準（オプション）

もし `scripts/print-html.sh` を置く場合：
- [ ] 以下のコマンドで out/**/index.html が生成される：
  ```bash
  cue export -e render.renderedPages | ./scripts/print-html.sh
  ```
- [ ] スクリプトは500行未満（IOラッパーとして最小限）
- [ ] テンプレート処理・条件分岐・レイアウト変更は一切しない

### 3.4 ドキュメントの基準

- [ ] README.md に以下が記載される：
  - プロジェクト目的（「CUEでHTML生成API提供」）
  - 環境構築手順（CUEのインストール）
  - `cue export -e render.renderedPages` の使用例
  - サンプルスクリプトの説明（オプション）
  - 3レイヤー構造の説明

---

## 4. 作業計画（4 Phase）

### Phase 1: 環境セットアップ（1h）

**目的**: CUEモジュールと基本構造を準備

**タスク**:
1. `cue.mod/module.cue` 作成
2. ディレクトリ作成: `schema/`, `content/`, `render/`, `scripts/`
3. `.gitignore` 作成（`out/` を無視）
4. `README.md` 初期版作成

**完了条件**:
- `cue version` が動作する
- ディレクトリ構造が整っている

---

### Phase 2: スキーマ定義（2h）

**目的**: #Fragment/#Section/#Page 型を定義し、バリデーションルールを実装

**タスク**:
1. `schema/model.cue` 作成
   - `#Fragment`, `#Section`, `#Page` 定義
2. `schema/validation.cue` 作成
   - path重複、fragmentId参照、level制約、H1制約

**完了条件**:
- `cue vet ./schema` が通る
- 制約違反の例でエラーが出ることを確認

---

### Phase 3: レンダリング実装（3-4h）

**目的**: CUE で HTML 文字列を組み立て、renderedPages を出力

**タスク**:
1. `render/html.cue` 作成
   - `headHtml(page)` 実装（htmx CDN含む）
   - `sectionHtml(section, fragment)` 実装
   - `pageHtml(page)` 実装
   - `renderedPages` 構造出力

2. `content/fragments.cue` 作成
   - 3つ程度のサンプルフラグメント

3. `content/pages.cue` 作成
   - docs/article/lp 各1ページ定義

**完了条件**:
- `cue export -e render.renderedPages` で JSON が出力される
- JSON の構造が `[{ path: string, html: string }]`
- html に `<!DOCTYPE html>` が含まれる
- html に `htmx.org` が含まれる

---

### Phase 4: 検証とサンプルスクリプト（2h）

**目的**: DoD を満たすことを確認し、サンプルスクリプトを作成

**タスク**:
1. `cue vet ./...` でバリデーション確認
2. 代表3ページをブラウザで手動確認（JSON の html をファイルに保存して開く）
3. （オプション）`scripts/print-html.sh` 作成
   - 標準入力からJSONを読み、out/**/index.html に書き出し
4. README.md に使用例を追加

**完了条件**:
- 全DoDチェックボックスがON
- README に cue export の使用例が記載されている

---

## 5. 未解決事項（最小限）

### 5.1 フラグメント粒度
- **現状**: 1段落単位 vs 1セクション単位が未決定
- **決定方法**: Phase 3 でサンプル作成しながら判断

### 5.2 docs/article/lp のレイアウト差
- **v1方針**: 最低限（サイドバー有無、ヘッダー有無）に留める
- **詳細**: Phase 3 で `render/html.cue` の `pageHtml` 内で kind による分岐を実装

---

## 6. 明示的な範囲外（v1では実装しない）

以下は**このrepoの責務ではない**、または**将来の拡張**として扱う：

### このrepoの責務外
- ❌ **Makefile/Build システム** - 使いたい人が別レイヤーで設定
- ❌ **CI/CD設定** - GitHub Actions等は利用者が設定
- ❌ **Nix環境** - CUEさえあれば動く前提
- ❌ **テストフレームワーク** - DoDは手動確認で十分
- ❌ **プリンタの複雑化** - サンプルスクリプトは500行未満厳守

### 将来の拡張（Phase 7+）
- ❌ **hx-get 動的差し替え** - v1では htmx CDN読み込みのみ
- ❌ **sitemap/robots/llms.txt 生成** - 別プロジェクトor Phase 8
- ❌ **マルチサイト対応** - Phase 9
- ❌ **差分ビルド** - パフォーマンス問題が出たら
- ❌ **HTML minify** - 必要になったら

---

## 7. アーキテクチャの核心（再確認）

### 3つのレイヤー

```
┌─────────────────────────────────────┐
│   Schema Layer (型・制約)            │
│   schema/model.cue                  │
│   schema/validation.cue             │
└─────────────────────────────────────┘
              ↓ 使用
┌─────────────────────────────────────┐
│   Content Layer (値)                │
│   content/fragments.cue             │
│   content/pages.cue                 │
└─────────────────────────────────────┐
              ↓ 変換
┌─────────────────────────────────────┐
│   Render Layer (HTML生成)           │
│   render/html.cue                   │
│   → renderedPages 出力              │
└─────────────────────────────────────┘
              ↓ export
         (このrepoのゴール)
```

### このrepoの成果物
**`cue export -e render.renderedPages` で得られるJSON**

それ以外（ファイル書き出し、デプロイ、CI等）は利用者の責任範囲。

---

## 8. マイルストーン

| マイルストーン | 完了条件 | 期日目安 |
|--------------|---------|---------|
| M1: 環境構築 | cue.mod作成、ディレクトリ準備 | Day 1 |
| M2: スキーマ完成 | `cue vet ./schema` 成功 | Day 2 |
| M3: renderedPages 出力 | `cue export` でJSON取得 | Day 3 |
| M4: DoD達成 | 全チェックボックスON | Day 4 |

---

## 9. 次のアクション

### 実装開始前の確認
- [ ] この v3 方針に合意
- [ ] Phase 1 から順次着手

### Phase 1 開始時
1. `cue.mod/module.cue` 作成
2. ディレクトリ作成
3. `.gitignore` 作成
4. `README.md` 初期版作成

---

この v3 計画書は、**「CUEでpath+htmlを出すこと」に徹底的に集中**した設計です。
それ以外の複雑さ（Build/Printer/CI等）は全て範囲外とし、利用者が必要に応じて追加する前提です。
