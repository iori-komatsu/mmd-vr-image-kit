mod cube2pano;

use anyhow::{bail, Context};
use image::ImageReader;
use std::path::{Path, PathBuf};
use structopt::StructOpt;

#[derive(Debug, StructOpt)]
#[structopt(
    name = "cube2pano",
    about = "キューブマップ画像を合成してVR画像(Equirectangular)を作成する"
)]
struct Opt {
    #[structopt(
        parse(from_os_str),
        help = "入力画像のうち任意の一枚を指定する。それ以外の画像は命名規則から自動的に推測される。"
    )]
    input_example: PathBuf,

    #[structopt(parse(from_os_str), help = "出力されるVR画像のファイル名")]
    output: PathBuf,

    #[structopt(long = "180", help = "180度画像を出力する")]
    vr180: bool,

    #[structopt(
        short = "m",
        long = "monaural",
        help = "ステレオ画像ではなく普通の画像を出力する"
    )]
    monaural: bool,
}

fn get_file_prefix_of_monaural_image(file_stem: &str) -> anyhow::Result<&str> {
    for d in &cube2pano::DIRECTIONS {
        if file_stem.ends_with(d.name) {
            let end = file_stem.len() - d.name.len();
            return Ok(&file_stem[0..end]);
        }
    }
    bail!("The file name of the input image does not follow the naming convention.");
}

fn get_file_prefix_of_stereo_image(file_stem: &str) -> anyhow::Result<&str> {
    for lr in ["L_", "R_"] {
        for d in &cube2pano::DIRECTIONS {
            let suffix = lr.to_owned() + d.name;
            if file_stem.ends_with(&suffix) {
                let end = file_stem.len() - suffix.len();
                return Ok(&file_stem[0..end]);
            }
        }
    }
    bail!("The file name of the input image does not follow the naming convention.");
}

fn main() -> anyhow::Result<()> {
    let opt = Opt::from_args();

    let Some(input_dir) = Path::new(&opt.input_example).parent() else {
        bail!("Input image path is invalid")
    };
    let Some(file_stem) = Path::new(&opt.input_example).file_stem() else {
        bail!("Input image path is invalid")
    };
    let Some(file_ext) = Path::new(&opt.input_example).extension() else {
        bail!("Input image path is invalid")
    };
    let input_dir = input_dir.to_string_lossy().into_owned();
    let file_stem = file_stem.to_string_lossy().into_owned();
    let file_ext = file_ext.to_string_lossy().into_owned();

    let output = if opt.monaural {
        // 画像をロード
        let prefix = get_file_prefix_of_monaural_image(&file_stem)?;
        let mut images = Vec::new();
        for d in &cube2pano::DIRECTIONS {
            if opt.vr180 && d.name == "back" {
                continue;
            }
            let base = format!("{}{}.{}", prefix, d.name, file_ext);
            let path = Path::new(&input_dir).join(base);
            let img = ImageReader::open(&path)
                .with_context(|| format!("Failed to open {}", path.to_string_lossy()))?
                .decode()?;
            eprintln!("Loaded: {}", path.to_string_lossy());
            images.push(img);
        }
        // VR画像を合成
        cube2pano::make_monaural_vr_image(&images)?
    } else {
        // 画像をロード
        let prefix = get_file_prefix_of_stereo_image(&file_stem)?;
        let mut stereo_images: Vec<Vec<_>> = Vec::new();
        for lr in ["L", "R"] {
            let mut images = Vec::new();
            for d in &cube2pano::DIRECTIONS {
                if opt.vr180 && d.name == "back" {
                    continue;
                }
                let base = format!("{}{}_{}.{}", prefix, lr, d.name, file_ext);
                let path = Path::new(&input_dir).join(base);
                let img = ImageReader::open(&path)
                    .with_context(|| format!("Failed to open {}", path.to_string_lossy()))?
                    .decode()?;
                eprintln!("Loaded: {}", path.to_string_lossy());
                images.push(img);
            }
            stereo_images.push(images);
        }
        // VR画像を合成
        cube2pano::make_stereo_vr_image(&stereo_images[0], &stereo_images[1])?
    };

    // 画像を保存
    output.save(&opt.output)?;
    eprintln!("Saved: {}", opt.output.to_string_lossy());

    Ok(())
}
