#Requires AutoHotkey v2.0

MMDExportCubemap(output_dir, file_prefix, image_format, fov, is_stereo, ipd_model, ipd_mm) {
    ; MMDの単位で表したIPD
    ; 1MMD単位 = 80mm
    ipd_mmd := ipd_mm / 80.0

    ; パラメータを並べたもの
    table := [
        Map("name", "left",   "rx",   "0.0", "ry",  "90.0", "rz", "0.0"),
        Map("name", "right",  "rx",   "0.0", "ry", "-90.0", "rz", "0.0"),
        Map("name", "top",    "rx", "-90.0", "ry",   "0.0", "rz", "0.0"),
        Map("name", "bottom", "rx",  "90.0", "ry",   "0.0", "rz", "0.0"),
        Map("name", "front",  "rx",   "0.0", "ry",   "0.0", "rz", "0.0"),
    ]
    if fov == "360" {
        table.Push(Map("name", "back",   "rx",   "0.0", "ry", "180.0", "rz", "0.0"))
    }

    main_window := WinExist("ahk_class Polygon Movie Maker")
    if main_window == 0 {
        MsgBox("MMD のウィンドウが見つかりませんでした。", "Runtime Error", "iconx")
        return
    }

    MakeFileName(lr, name) {
        if is_stereo {
            return output_dir . "\" . file_prefix . lr . "_" . name . "." . image_format
        } else {
            return output_dir . "\" . file_prefix . name . "." . image_format
        }
    }

    if is_stereo {
        lrs := ["L", "R"]
    } else {
        lrs := ["N"]
    }

    for lr in lrs {
        ; IPD を設定
        if lr != "N" {
            ControlChooseString(ipd_model, "ComboBox3")
            Sleep(250)
            if lr == "L" {
                sign := -1.0
            } else {
                sign := 1.0
            }
            ControlSetText(String(sign * ipd_mmd / 2.0), "Edit26") ; ボーン位置の X
            ControlSend("{Enter}", "Edit26")
            Sleep(250)
        }

        for params in table {
            ; カメラの角度を設定
            ControlChooseIndex(1, "ComboBox3") ; "カメラ・照明・アクセサリ" を選択
            Sleep(250)
            ControlSetText(params["rx"], "Edit29") ; 角度X
            ControlSend("{Enter}", "Edit29")
            Sleep(250)
            ControlSetText(params["ry"], "Edit30") ; 角度Y
            ControlSend("{Enter}", "Edit30")
            Sleep(250)
            ControlSetText(params["rz"], "Edit31") ; 角度Z
            ControlSend("{Enter}", "Edit31")
            Sleep(250)

            ; 画像を保存する
            MenuSelect("", "", "1&", "7&") ; [ファイル] -> [画像ファイルに出力]
            Sleep(500)
            WinWait("ahk_class #32770") ; 保存ダイアログを待つ
            file_name := MakeFileName(lr, params["name"])
            ControlSetText(file_name, "Edit1") ; ファイル名入力
            ControlSend("{Enter}")
            Sleep(500)
            while WinExist("名前を付けて保存の確認") {
                ControlClick("はい(&Y)")
                Sleep(1500)
            }
            ; 録画画面が出てくるまで待つ
            WinWait("ahk_class RecWindow",, 30)
            ; 録画画面が消えるまで待つ
            while WinExist("ahk_class RecWindow") {
                Sleep(500)
            }

            ; メインウィンドウを選択
            if WinExist("ahk_id " main_window) == 0 {
                MsgBox("MMDメインウィンドウが見つかりません。", "Runtime Error", "iconx")
                Exit
            }
            ; MMD がメッセージを受け付けられるようになるまで待つ
            SendMessage(0,,,,,,,, 60000) ; Send WM_NULL
            ; これでも稀にタイムアウトするのでもうちょっと待つ
            Sleep(3000)
        }
    }

    MsgBox("画像の書き出しが完了しました。", "完了")
}

ShowGui() {
    setting_dialog := Gui(, "MMD でキューブマップを書き出すやつ")

    ; 書き出し先フォルダ
    setting_dialog.AddText(, "書き出し先フォルダ: ")
    edit_output_dir := setting_dialog.AddEdit("w400", A_Desktop)
    SetOutputDir(*) {
        dir := DirSelect(,, "書き出し先のフォルダを選択")
        if dir {
            edit_output_dir.Text := dir
        }
    }
    setting_dialog.AddButton("w40 x+8", "...").OnEvent("Click", SetOutputDir)

    ; ファイル名の接頭辞
    setting_dialog.AddText("xm0", 'ファイル名の接頭辞 (※ これの後ろに "L_front.jpg" のような名前が追加されて保存されます):')
    edit_file_prefix := setting_dialog.AddEdit("xm0 w400", "cubemap_")

    ; ファイル形式
    setting_dialog.AddText("xm0 y+12", "画像のフォーマット: ")
    combo_format := setting_dialog.AddComboBox("x+8 Choose1 w60", ["jpg", "png"])

    ; 視野角
    setting_dialog.AddText("xm0", "VR360 or VR180: ")
    combo_fov := setting_dialog.AddComboBox("x+8 Choose1 w60", ["360", "180"])

    ; Stereo/Mono
    StereoClicked(*) {
        edit_ipd_model.Enabled := check_stereo.Value
        edit_ipd.Enabled := check_stereo.Value
    }
    check_stereo := setting_dialog.AddCheckbox("xm0 y+12 Checked", "ステレオ画像")
    check_stereo.OnEvent("Click", StereoClicked)

    ; IPD
    setting_dialog.AddText("xm16 y+12", "瞳孔間距離(mm): ")
    edit_ipd := setting_dialog.AddEdit("x+8 w60", "64")

    ; IPD設定用のモデルの名前
    setting_dialog.AddText("xm16", "IPD設定用のモデルの名前:")
    edit_ipd_model := setting_dialog.AddEdit("xm20 w400", "CameraIPD")

    ; 注意書き
    setting_dialog.AddText("xm0 y+16", "※ 自動操作中はMMDに触れないでください！")

    ; 書き出し開始
    StartExporting(*) {
        output_dir := Trim(edit_output_dir.Text, '"')
        if !DirExist(output_dir) {
            MsgBox("書き出し先フォルダが存在しません", "Invalid Argument", "Iconx")
            return
        }
        file_prefix := edit_file_prefix.Text
        image_format := combo_format.Text
        fov := combo_fov.Text
        is_stereo := check_stereo.Value
        ipd_model := edit_ipd_model.Text
        try {
            ipd_mm := Float(edit_ipd.Text)
        } catch {
            MsgBox("瞳孔間距離に数値でない文字列が入力されています", "Invalid Argument", "Iconx")
            return
        }

        setting_dialog.Hide()
        MMDExportCubemap(output_dir, file_prefix, image_format, fov, is_stereo, ipd_model, ipd_mm)
        setting_dialog.Show()
    }
    setting_dialog.AddButton("xm0 w140", "書き出し開始！").OnEvent("Click", StartExporting)

    setting_dialog.Show()
}

ShowGui()
