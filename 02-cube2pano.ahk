#Requires AutoHotkey v2.0

ExecuteCommand(cmd) {
    DllCall("Kernel32\AllocConsole")
    shell := ComObject("WScript.Shell")
    exec := shell.Exec(cmd)
    stderr := exec.StdErr.ReadAll()
    exitcode := exec.ExitCode
    DllCall("Kernel32\FreeConsole")
    if exitcode != 0 {
        MsgBox("cube2pano.exe の実行に失敗しました。`n`n実行ログ:`n" . stderr, "Runtime Error", "iconx")
        return
    }
    MsgBox("VR画像を生成しました", "完了")
}

ExecuteCube2pano(input_file, output_file, fov, is_stereo) {
    cmd := A_ScriptDir . "\bin\cube2pano.exe "
    if fov == "180" {
        cmd := cmd . "--180 "
    }
    if !is_stereo {
        cmd := cmd . "--monaural "
    }
    cmd := cmd . '"' . input_file . '" '
    cmd := cmd . '"' . output_file . '"'
    ExecuteCommand(cmd)
}

ShowGui() {
    dlg := Gui(, "キューブマップ画像を結合してVR画像を生成するやつ")

    ; 入力画像
    dlg.AddText(, "入力画像 (書き出されたキューブマップ画像のうち、どれでもいいので一枚選択してください):")
    edit_input_file := dlg.AddEdit("w400", "")
    SetInputFile(*) {
        f := FileSelect(1,, "入力画像", "Image File (*.jpg; *.jpeg; *.png; *.bmp; *.webp)")
        if f {
            edit_input_file.Text := f
        }
    }
    dlg.AddButton("w40 x+8", "...").OnEvent("Click", SetInputFile)

    ; 出力画像
    dlg.AddText("xm0", "出力画像のファイル名:")
    edit_output_file := dlg.AddEdit("w400", "")
    SetOutputFile(*) {
        f := FileSelect("S16",, "出力画像", "Image File (*.jpg; *.jpeg; *.png; *.bmp; *.webp)")
        if f {
            SplitPath(f,,, &ext,,,)
            if ext == "" {
                f := f . ".png"
            }
            edit_output_file.Text := f
        }
    }
    dlg.AddButton("w40 x+8", "...").OnEvent("Click", SetOutputFile)

    ; 視野角
    dlg.AddText("xm0", "VR360 or VR180: ")
    combo_fov := dlg.AddComboBox("x+8 Choose1 w60", ["360", "180"])

    ; Stereo/Mono
    check_stereo := dlg.AddCheckbox("xm0 Checked", "ステレオ画像")

    Doit(*) {
        input_file := Trim(edit_input_file.Text, '"')
        if !FileExist(input_file) {
            MsgBox("入力画像が存在しません", "Invalid Argument", "Iconx")
            return
        }
        output_file := Trim(edit_output_file.Text, '"')
        if output_file == "" {
            MsgBox("出力画像のファイル名が指定されていません", "Invalid Argument", "Iconx")
            return
        }
        fov := combo_fov.Text
        is_stereo := check_stereo.Value

        dlg.Hide()
        ExecuteCube2pano(input_file, output_file, fov, is_stereo)
        dlg.Show()
    }
    dlg.AddButton("xm0 w140", "生成！").OnEvent("Click", Doit)

    dlg.Show()
}

ShowGui()
