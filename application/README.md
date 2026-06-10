# application/ — 바로가기 아이콘 폴더

`shortcuts.txt` 의 `custom:` 항목에서 쓸 **아이콘 이미지**를 이 폴더에 넣습니다.

사용법: 이미지 파일(`png`/`svg` 등)을 여기에 두고, `shortcuts.txt` 의 아이콘 칸에
그 **파일명**을 적으면 됩니다.

```
# application/mylogo.png 를 아이콘으로 사용
custom: 내 사이트 | xdg-open https://example.com | mylogo.png
```

`update.sh` 는 아이콘 값이 이 폴더의 파일이면 그 이미지를, 아니면 시스템 아이콘
이름(`web-browser` 등)으로 처리합니다.
