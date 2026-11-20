# Pictures

Pictures in the app must be free to reuse or made for the app; every picture gets an entry here, and every bundled picture a credit on the Sources page.

## Bundled

All of the following six were supplied by the owner on 2026-11-11, generated with ChatGPT from the owner's own mockup (`design/mockups/home_dark.png`), and converted to JPEG (longest side at most 1600, quality 85, progressive, no metadata) by `tools/convert_ui_pictures.py` from the PNGs in `source_material/ui_pictures/` (untracked).

`assets/pictures/hero_dark.jpg` — JPEG, 1600 x 800, 132,884 bytes, SHA-1 `4d5e57e2a978728b518110e04f2bb8ee6aa1459b`. Used as the featured card picture of Buddha Wandanawa (`cat-namaskaraya`) in the dark theme.

`assets/pictures/hero_light.jpg` — JPEG, 1600 x 800, 157,602 bytes, SHA-1 `5971a6d311ad34799fb6048561c75daa251ab8a5`. Used as the featured card picture of Buddha Wandanawa (`cat-namaskaraya`) in the light theme.

`assets/pictures/header_dark.jpg` — JPEG, 1600 x 533, 43,552 bytes, SHA-1 `35b924f1672f6a9499a9553aafcdd13b960ad849`. Used behind the Home header in the dark theme.

`assets/pictures/header_light.jpg` — JPEG, 1600 x 533, 61,580 bytes, SHA-1 `774a2caa935e55d72c19731cb1b3747a3a2ed014`. Used behind the Home header in the light theme.

`assets/pictures/buddha_wandanawa.jpg` — replaces the file of 2026-11-10. JPEG, 1448 x 1086, 179,903 bytes, SHA-1 `2417cf52fc03f1b77e2418ce228f1d1140ea46d1`. Used on the Buddha Wandanawa card (`cat-namaskaraya`).

`assets/pictures/pirith.jpg` — replaces the file of 2026-11-10. JPEG, 1448 x 1086, 284,264 bytes, SHA-1 `c6d1851d233d64e9d8141d91a4a5d9fbfaed9fb1`. Used on the Pirith card and Library row (`cat-pirith`).

`assets/pictures/home_banner.jpg` is no longer bundled (removed from `pubspec.yaml` and the app); the hero pictures replace it. `design/card_images/home_banner.jpg` remains as a copy.

`assets/pictures/samantha_patthana.jpg` — supplied by the owner on 2026-11-10, generated with an AI image tool (the tool was not recorded). JPEG, 1280 x 720, 159,267 bytes, SHA-1 `bcc99eea8c0d821f3af832b4bdf540c42315a9ba`. Used on the Samantha Pattana card and Library row (`cat-samantha-patthana`). A byte-for-byte copy of `design/card_images/stupa_dusk.jpg`.

## Kept for later, not bundled

In `design/card_images/` (not listed in `pubspec.yaml`). Same origin as above: supplied by the owner on 2026-11-10, generated with an AI image tool (the tool was not recorded).

| File | Pixels | SHA-1 | Meant for |
|---|---|---|---|
| `pirith.jpg` | 1600 x 900 | `461ee9b62b683276482de9994c4c58d606cc7344` | now bundled as `assets/pictures/pirith.jpg` |
| `bodhi_tree.jpg` | 1600 x 900 | `b66ad8f7214b7b71488d9b6330ae7f85953a84ee` | the Meditation topic |
| `stupa_dusk.jpg` | 1280 x 720 | `bcc99eea8c0d821f3af832b4bdf540c42315a9ba` | now bundled as `assets/pictures/samantha_patthana.jpg` |

`design/card_images/buddha_wandanawa.jpg` is a copy of the earlier bundled picture (now replaced); `design/card_images/home_banner.jpg` is a copy of the removed banner. `design/card_images/pirith.jpg` is likewise the earlier Pirith picture.

In `source_material/ui_pictures/` (untracked; supplied by the owner on 2026-11-11, generated with ChatGPT from the owner's mockup): `continue_thumb.png`, `statue_tall_warm.png` and `statue_tall_dark.png` are kept there, unused and not bundled.

## Book covers

The covers of the 23 books of Ven. Rerukane Chandawimala Maha Nahimi, as published by the Sri Chandawimala Dhamma Treatises Preservation Board on rerukanemahanahimi.lk, downloaded by `python -I -X utf8 tools/sync_books.py . --covers` into `assets/books/covers/`. Permission is pending (see the release checklist). Table made by a small script from the files and `assets/books/index.json`.

| File | Pixels | Bytes | SHA-1 | Source | Status |
|---|---|---|---|---|---|
| `bauddhayage-athpotha.png` | 377 x 567 | 50,747 | `c65bef9157d90aacf00b11075e72e1e025744610` | https://rerukanemahanahimi.lk/uploads/covers/cover_1778524650.png | published by the Board; permission pending |
| `dharma-winishchaya.png` | 376 x 568 | 30,855 | `4d4f24277c6225dd2d88de7a483ac5e391ff31f0` | https://rerukanemahanahimi.lk/uploads/covers/book11-dharma-winishchaya.png | published by the Board; permission pending |
| `paramitha-prakaranaya.png` | 378 x 569 | 28,150 | `a20c443d1a7c91f29d91fb2f1bd8e97868ee796b` | https://rerukanemahanahimi.lk/uploads/covers/book12-paramitha-prakaranaya.png | published by the Board; permission pending |
| `suvisi-gunaya.png` | 227 x 345 | 118,535 | `905fc4839382a49f2f94ea074b89dc22fcd8aebb` | https://rerukanemahanahimi.lk/uploads/covers/book18-suvisi-maha-gunaya.jpg | published by the Board; permission pending |
| `abhidharmaye-mulika-karunu.png` | 377 x 568 | 29,189 | `0103e1cd69962f8265960ed44d9f7fa2819b105f` | https://rerukanemahanahimi.lk/uploads/covers/cover_1778516443.png | published by the Board; permission pending |
| `abhidharma-margaya.png` | 375 x 568 | 56,613 | `fee3c9b2c198936433d48df0f06e43e987f379f8` | https://rerukanemahanahimi.lk/uploads/covers/cover_1778521367.png | published by the Board; permission pending |
| `chathurarya-sathya.png` | 383 x 567 | 20,700 | `e5f4c4627bbd9f346e9b6e6bfd46a5ca80cc6f2d` | https://rerukanemahanahimi.lk/uploads/covers/cover_1778524474.png | published by the Board; permission pending |
| `punyopadeshaya.png` | 377 x 567 | 41,804 | `e976a0a6dfdc4ebd820e1a8cd935d0a5e489be64` | https://rerukanemahanahimi.lk/uploads/covers/book09-punyopadeshaya.png | published by the Board; permission pending |
| `shasanavatharanaya.png` | 376 x 567 | 52,637 | `b2a7846f5c4ecc403efff1d304630aaf66012f51` | https://rerukanemahanahimi.lk/uploads/covers/book28-sasanavatharanaya.png | published by the Board; permission pending |
| `bodhi-pakshika-dharma.png` | 378 x 568 | 41,959 | `3a4ea2450915dcb6e194d09ce73c1dff13ecbdb5` | https://rerukanemahanahimi.lk/uploads/covers/book13-bodhipakshika-dharma-vistharaya.png | published by the Board; permission pending |
| `patichcha-samuppada-vivaranaya.png` | 378 x 568 | 44,335 | `964d19fff80a23e3b658ff79e9f573071e888f5f` | https://rerukanemahanahimi.lk/uploads/covers/cover_1778524122.png | published by the Board; permission pending |
| `upasampada-sheelaya.png` | 376 x 568 | 19,323 | `6a2f7300e4045147194a76f3d6d4c1f6006fab14` | https://rerukanemahanahimi.lk/uploads/covers/book27-upasampada-sheelaya.png | published by the Board; permission pending |
| `ubhaya-prathimokshaya.png` | 400 x 529 | 465,492 | `ad6cef1673eaf7ed1b8f7626705edcf8e45a4fd1` | https://rerukanemahanahimi.lk/uploads/covers/book25-ubaya-pratimokshaya.png | published by the Board; permission pending |
| `wanchaka-dharma.png` | 378 x 568 | 37,675 | `87843eead2d4eee61ce2c10630702764d75fa356` | https://rerukanemahanahimi.lk/uploads/covers/book20-vanchaka-dharma.png | published by the Board; permission pending |
| `vidarshana-bhavana-kramaya.png` | 379 x 567 | 35,212 | `3c0b6cbcb1071d0dcee791390cfbbd9c6069ddb0` | https://rerukanemahanahimi.lk/uploads/covers/book24-vidarshana-bhavana-kramaya.png | published by the Board; permission pending |
| `keles-1500.png` | 375 x 567 | 22,585 | `a8b3cf0c243317665cf4582d0709496d2e2d81c2` | https://rerukanemahanahimi.lk/uploads/covers/book19-keles-eka-dahas-pansiyaya.png | published by the Board; permission pending |
| `pohoya-dinaya.png` | 378 x 568 | 26,622 | `5f061fef322e0cba460702de217153b48468d1d0` | https://rerukanemahanahimi.lk/uploads/covers/book16-pohoya-dinaya.png | published by the Board; permission pending |
| `bodhi-poojawa.png` | 379 x 568 | 35,387 | `6774c0aab0c93f1f5bff0e84864a36db99086fcd` | https://rerukanemahanahimi.lk/uploads/covers/book15-bodhi-pujava.png | published by the Board; permission pending |
| `chaththalisakara-vipassana.png` | 380 x 566 | 26,554 | `94d9df3f7bc1557efaf8e5b8bd6a40874fc29af6` | https://rerukanemahanahimi.lk/uploads/covers/book23-chaththaleesakara-vipassana.png | published by the Board; permission pending |
| `vinaya-karma.png` | 379 x 567 | 36,100 | `5478014ca99d694fe59b0ea36cee3144551aa145` | https://rerukanemahanahimi.lk/uploads/covers/book26-vinayakarma-potha.png | published by the Board; permission pending |
| `sathipttana-bhavana-kramaya.png` | 380 x 569 | 48,931 | `3859e61f42814ce09748c4ecd46f93ada421a44b` | https://rerukanemahanahimi.lk/uploads/covers/book22-satipatthana-bhavana-kramaya.png | published by the Board; permission pending |
| `nirvana-vinishchaya.png` | 378 x 568 | 35,545 | `10b2423705dd95206adb46b667a46d849067ff42` | https://rerukanemahanahimi.lk/uploads/covers/book10-nirvana-vinishchaya.png | published by the Board; permission pending |
| `pattana-pakarana-sannaya.png` | 227 x 345 | 120,460 | `aa3c7d52cdf8c7532bbefc329582539ca9890803` | https://rerukanemahanahimi.lk/uploads/covers/cover_1778523520.jpg | published by the Board; permission pending |

## Book pictures

Pictures inside the books, from pitaka.lk (the Board's pictures, as served there), bundled as `assets/books/pictures/<book>-<hash>.png` by `tools/sync_books.py . --pictures`. Permission is pending (see the release checklist).

| File | Pixels | Bytes | SHA-1 | Source | Status |
|---|---|---|---|---|---|
| `bodhi-poojawa-377a05be20.png` | 306 x 302 | 175,952 | `587c54c8eb2b26542f41add7a22bd758d67e414f` | https://pitaka.lk/books/bodhi-poojawa/images/377a05be20.png | published by the Board; permission pending |
| `patichcha-samuppada-vivaranaya-1c0c841a77.png` | 532 x 495 | 109,752 | `036881f0dc2d8411dcec13a390d49bca3bd969cd` | https://pitaka.lk/books/patichcha-samuppada-vivaranaya/images/1c0c841a77.png | published by the Board; permission pending |
| `patichcha-samuppada-vivaranaya-7000cfd54f.png` | 542 x 495 | 76,305 | `d96d99ff637d0c78bcd3aa936bc77b883fc4630f` | https://pitaka.lk/books/patichcha-samuppada-vivaranaya/images/7000cfd54f.png | published by the Board; permission pending |
| `patichcha-samuppada-vivaranaya-7d52f1f4fb.png` | 560 x 497 | 80,807 | `44dc4b8a5e29405baaf2557791da3219bd84aca5` | https://pitaka.lk/books/patichcha-samuppada-vivaranaya/images/7d52f1f4fb.png | published by the Board; permission pending |
| `patichcha-samuppada-vivaranaya-8e362bcd6f.png` | 504 x 525 | 112,331 | `8a7b1d2d33b7e588d828ea028d9772a6c2e4d102` | https://pitaka.lk/books/patichcha-samuppada-vivaranaya/images/8e362bcd6f.png | published by the Board; permission pending |
| `patichcha-samuppada-vivaranaya-f8e98e64c7.png` | 468 x 266 | 36,611 | `35eb958e3a5a0b09878ac175e22739808b67b96a` | https://pitaka.lk/books/patichcha-samuppada-vivaranaya/images/f8e98e64c7.png | published by the Board; permission pending |
| `punyopadeshaya-12de55acba.png` | 573 x 292 | 36,804 | `3d7d8fc1e7c162621072aaf3a694f93cf303d6b8` | https://pitaka.lk/books/punyopadeshaya/images/12de55acba.png | published by the Board; permission pending |
| `punyopadeshaya-75000eeb95.png` | 576 x 191 | 19,160 | `4ec89b766580778bfb85ebf31e4aad500ed3f7b3` | https://pitaka.lk/books/punyopadeshaya/images/75000eeb95.png | published by the Board; permission pending |
| `punyopadeshaya-d6288217fb.png` | 446 x 336 | 44,384 | `103f7e8814cbf0cf485d98f7b06042d7d9dde573` | https://pitaka.lk/books/punyopadeshaya/images/d6288217fb.png | published by the Board; permission pending |
| `punyopadeshaya-f0e108d355.png` | 472 x 251 | 52,702 | `7107d2e0b291ff0e2526cd5601e7160dc236a0ef` | https://pitaka.lk/books/punyopadeshaya/images/f0e108d355.png | published by the Board; permission pending |

## No longer used

The Wikimedia Commons photograph `File:Samadhi Statue Anuradhapura.jpg` by Price Zero (CC0) was on the card in commit `48eee81` and was replaced by the owner's picture.
