"""itch.io 업로드용 폴더·zip 을 만든다.  사용: python itch/pack.py <버전>   (예: python itch/pack.py 0.62)
프로젝트 루트의 ParryPierce.exe (Godot 내보내기 결과)를 itch/build/windows/ 로 복사하고 README.txt 를 붙인 뒤
itch/ParryPierce-v<버전>-windows.zip 도 만든다. 웹 내보내기(itch/build/web/index.html, "Web" 프리셋)가 있으면
itch/ParryPierce-v<버전>-web.zip 도 만든다 (index.html 이 zip 맨 위에 오게). 용량이 커서 build/ 와 zip 은 git 에 올리지 않는다 (.gitignore)."""
import os
import shutil
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

README = """PARRY PIERCE  v{ver}
==================

[English]
Parry the barrage, ride the energy back, and pierce the colossus.

Run:      double-click ParryPierce.exe (Windows 64-bit, mouse required)
Language: choose English / Korean with the flag buttons at the bottom-right of the main menu
Controls: Mouse = aim (up = glide) / Left-click = dash, hold = Charge Strike /
          Right-click (hold) = parry -> slow-mo aim -> release = Reverse Drive /
          R = restart / Esc = menu / F11 = fullscreen
Saves:    %APPDATA%\\Godot\\app_userdata\\Parry Pierce (prototype)\\   (delete the folder to reset)
Note:     the exe is not code-signed, so Windows SmartScreen may warn ("More info" -> "Run anyway").
          The game uses no network and collects no data.

[한국어]
탄막을 패리하고, 받아낸 힘으로 거대 병기를 꿰뚫어라.

실행:    ParryPierce.exe 더블클릭 (Windows 64비트, 마우스 필요)
언어:    메인 화면 우하단의 국기 버튼으로 영어/한국어 선택
조작:    마우스 = 조준(위 = 활공) / 좌클릭 = 돌진, 꾹 = 차지 강습 /
         우클릭 꾹 = 패리 -> 슬로우 조준 -> 놓으면 리버스 드라이브 /
         R 재시작 / Esc 메뉴 / F11 전체 화면
저장:    %APPDATA%\\Godot\\app_userdata\\Parry Pierce (prototype)\\   (폴더를 지우면 처음부터)
참고:    코드 서명이 없어 Windows SmartScreen 경고가 뜰 수 있습니다 ("추가 정보" -> "실행").
         네트워크를 쓰지 않고 데이터를 수집하지 않습니다.

Credits
-------
Sprite art: "Space Rage" by Ravenmore (http://dycha.net/) - CC-BY 3.0
Font: Galmuri11 by Lee Minseo (https://github.com/quiple/galmuri) - SIL Open Font License 1.1
Built with Godot Engine 4 (MIT).
"""


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit("usage: python itch/pack.py <version>   e.g. 0.49")
    ver = sys.argv[1]
    exe = os.path.join(ROOT, "ParryPierce.exe")
    if not os.path.exists(exe):
        sys.exit("ParryPierce.exe not found - export the Windows build first (see itch/UPLOAD.md)")
    out_dir = os.path.join(HERE, "build", "windows")
    shutil.rmtree(out_dir, ignore_errors=True)
    os.makedirs(out_dir)
    shutil.copy2(exe, os.path.join(out_dir, "ParryPierce.exe"))
    with open(os.path.join(out_dir, "README.txt"), "w", encoding="utf-8", newline="\r\n") as f:
        f.write(README.format(ver=ver))
    zip_path = os.path.join(HERE, "ParryPierce-v%s-windows.zip" % ver)
    for old in os.listdir(HERE):
        if old.startswith("ParryPierce-v") and (old.endswith("-windows.zip") or old.endswith("-web.zip")):
            os.remove(os.path.join(HERE, old))
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name in ("ParryPierce.exe", "README.txt"):
            z.write(os.path.join(out_dir, name), name)
    print("folder:", out_dir)
    print("zip:   %s (%.1f MB)" % (zip_path, os.path.getsize(zip_path) / 1e6))
    web_dir = os.path.join(HERE, "build", "web")
    if os.path.exists(os.path.join(web_dir, "index.html")):
        web_zip = os.path.join(HERE, "ParryPierce-v%s-web.zip" % ver)
        with zipfile.ZipFile(web_zip, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
            for name in sorted(os.listdir(web_dir)):
                z.write(os.path.join(web_dir, name), name)
        print("web:   %s (%.1f MB)" % (web_zip, os.path.getsize(web_zip) / 1e6))
    else:
        print("web:   (skipped - export the \"Web\" preset to itch/build/web/index.html first)")


if __name__ == "__main__":
    main()
