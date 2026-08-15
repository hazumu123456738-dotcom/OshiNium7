# finalcheck — History Log

## 2026-08-16 07:3x（初回監査）

- 公開判断: 公開前に重大な修正が必要
- 重大リスク: 1件（Assets.xcassetsに実在K-POPグループ(ATEEZ・xikers・Heart2Heart)の無許諾と見られる公式風写真がアプリバイナリに同梱されている。コードからの表示参照は見つからないが、.xcassets内のファイルはSwiftから未参照でも通常コンパイル済みバイナリに含まれ配布される）
- 公開前に絶対やること(優先度1): Assets.xcassets内のATEEZ.imageset/xikers.imageset/Heart2Heart.imagesetを削除する、またはライセンスの存在を確認する
- 専門家に確認すべきこと: 弁護士へ①上記画像の著作権・肖像権リスク②景品表示法の取引付随性の解釈(将来ポイント⇔サブスク連動時)
- その他の主要発見: Gemini API利用規約(WebFetchで一次情報確認)は18歳未満が主に利用しうるサービスへの組み込みを禁止しているが、OshiNiumは13歳以上を許容しAI機能を全ユーザーに提供しており矛盾がある。Gemini APIキーがクライアントバイナリに文字列埋め込みでありstrings解析等で抽出され得る。匿名チャット・会場口コミは匿名性ゆえに投稿者個別ブロックの導線が無い(Apple Guideline 1.2との整合がグレー)。ポイント制度は現行の無償限定設計であれば資金決済法の規制対象外である可能性が高い(業界団体FAQ一次情報で確認)。
- 前回からの変化: 初回のため無し

## 2026-08-16 07:5x（重大リスク1件を即時対応、ユーザーから「今すぐ削除する」の回答）

- 対応内容: Assets.xcassets内のATEEZ.imageset/xikers.imageset/Heart2Heart.imagesetを削除。ユーザーへ「Assets.xcassetsはビルドのたびにアプリバイナリへ焼き込まれるため、Firestoreのシードデータ(開発用グループドキュメント等)とは違い、リリース時の一括クリーンアップを待つとそれまでのTestFlight配布・Apple審査提出用ビルドにも写真が含まれ続けてしまう」旨を説明し、今すぐの削除に同意を得た。project.pbxprojはAssets.xcassetsがOshiNium7/直下(file-system-synchronizedグループ)にあるため編集不要、ファイル削除のみでビルド成功を確認。
- 残課題: Gemini APIキーの契約ティア確認(13〜17歳ユーザーへのAI機能提供がGemini API利用規約に抵触しないか)、プライバシーポリシーのAI送信範囲の記載拡充(URLEventExtractionService分)、匿名チャット・会場口コミでの投稿者個別ブロック導線、Gemini APIキーのクライアント埋め込み解消(中期)、Info.plistのNSPhotoLibraryUsageDescription拡充(軽微)は未着手のまま。
