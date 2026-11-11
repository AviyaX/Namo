# Bundled fonts

All fonts are variable TTFs from the google/fonts repository, licensed under the SIL Open Font License 1.1 (see the `OFL-*.txt` files). Source base: `https://raw.githubusercontent.com/google/fonts/main/ofl/`

| File | Source | sha256 |
|---|---|---|
| NotoSansSinhala.ttf | notosanssinhala/NotoSansSinhala[wdth,wght].ttf | 9bd93e407a278075be403324063bc94a7e306c44de4df81214e932330c22eecf |
| NotoSerif.ttf | notoserif/NotoSerif[wdth,wght].ttf | 4d8e6761424656867019081a1a01336f3cb086982682698714054fc33f782713 |
| NotoSerif-Italic.ttf | notoserif/NotoSerif-Italic[wdth,wght].ttf | e87acbc6c0efd0d9a20d6a8cbbda2b266c14be3a3a6f5af8ec9d7b2460570ad1 |
| Lora.ttf | lora/Lora[wght].ttf | 822a6621ccbe8d97d20ac88c1c41f5615c9c2c202eaa75f272cd452aac6475a7 |
| Lora-Italic.ttf | lora/Lora-Italic[wght].ttf | 22d8d8854b53807aa664ca34f2031a9ed57a1d0dea296b8b96cdd3aad937a2b3 |
| OFL-NotoSansSinhala.txt | notosanssinhala/OFL.txt | 2d6f7c43bce61f4b1919379f901bc613484f5285f520b6d29bb7c1f31b17e841 |
| OFL-NotoSerif.txt | notoserif/OFL.txt | cee9892f9f0cc8fe882c9e9537ee6a89621d86ee7ceaf70b02e2b2b1c25c061a |
| OFL-Lora.txt | lora/OFL.txt | 1d9a970809ac804b582a6ce7f0ebc4e7fefcbfd7ff6299cad35ee656a21be716 |

The `Roboto` family in `pubspec.yaml` is an alias for the bundled `Lora.ttf`. No Roboto file is shipped. Flutter web downloads Roboto from the internet unless a family with that name is bundled.
