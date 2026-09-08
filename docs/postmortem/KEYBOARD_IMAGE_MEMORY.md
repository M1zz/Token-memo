# 앱에서는 복사되는데 키보드에서는 안 되던 사진

> When attached the image in the snippet, can copy it from the app and paste it somewhere.
> However, cannot paste by using the keyboard.

사용자가 보낸 그대로다. 같은 단축어, 같은 사진인데 **앱에서는 되고 키보드에서만 안 된다.**

## 원인: 키보드는 사진 한 장을 펼칠 메모리가 없다

사진은 원본 그대로 PNG 로 저장된다(`MemoStore.saveImage` 는 `image.pngData()`, 저장 전에
줄이지 않는다). 아이폰 사진 한 장이면 3000x4000 쯤 되고, **펼치면 48MB** 다(픽셀당 4바이트).

키보드 익스텐션의 메모리 한도는 앱의 몇십 분의 일이다. 그 한 장이 한도를 넘긴다.
넘기면 iOS 가 익스텐션을 **조용히 죽인다.** 예외도, 에러 로그도, 화면의 경고도 없다.
사용자 눈에는 "눌렀는데 아무 일도 안 일어남" 하나로만 보인다.

앱에는 그 한도가 없다. 그래서 앱에서만 됐다.

### 두 자리에서 펼치고 있었다

| 자리 | 하던 일 |
| --- | --- |
| `ImageMemoButton` (키에 사진 그리기) | `onAppear` 마다 **원본 통째로** 로드. 캐시도 없음 |
| `copyImageToClipboard` (탭해서 복사) | 원본을 펼치고(48MB) `UIPasteboard.image` 로 **다시 인코딩**(또 한 벌) |

누르는 순간 두 번째가 겹친다. 그 자리에서 죽는다.

### 이미 알고 있었다

5.0.4 릴리즈 노트의 "남겨 둔 것 (다음 판)" 에 이렇게 적혀 있었다.

> `ImageMemoButton` 은 앱 목록(`ClipKeyboardListComponents`)과 달리 **썸네일 캐시도
> 다운샘플링도 없이** 원본을 `onAppear` 마다 로드한다. 메모리가 빠듯한 키보드
> 익스텐션이라 이미지 단축어가 많으면 위험하다.

적어 두고 미뤘고, 사용자가 먼저 찾았다.

## 고친 것

**원본을 펼치는 일을 익스텐션에서 없앴다.** 두 자리 모두 펼칠 이유가 없었다.

| 자리 | 지금 |
| --- | --- |
| 그리기 | `MemoStore.loadThumbnail(fileName:maxPixel:)` - ImageIO 가 **디코드 단계에서** 줄인다(400px). 원본 크기 버퍼가 아예 안 생긴다. 6MB 상한 `NSCache` 에 담는다 |
| 클립보드 | `MemoStore.imageData(fileName:)` - 파일 바이트를 **메모리 매핑으로** 읽어 `UIPasteboard.setData(_:forPasteboardType:)` 에 그대로 건넨다. 펼치지도, 다시 인코딩하지도 않는다 |

`UIImage` 를 거치지 않는 것이 핵심이다. 클립보드에 필요한 것은 픽셀이 아니라 파일이다.

## 곁에서 같이 나온 것: 글+사진 단축어는 사진이 사라졌다

앱의 `finalizeCopy` 가 이렇게 하고 있었다.

```swift
UIPasteboard.general.image = image        // 사진을 얹고
if mixed { UIPasteboard.general.string = processedValue }   // 글을 얹으면
```

**클립보드는 새로 얹을 때마다 앞의 것을 버린다.** 글을 넣는 순간 사진이 사라졌다.
글+사진 단축어를 앱에서 복사해도 사진은 안 붙던 이유다.

지금은 **한 항목에 두 표현을 함께** 담는다(`UIPasteboard.general.items = [item]`).
받는 앱이 자기가 받을 수 있는 쪽을 가져간다.

사진 파일을 못 읽었을 때 **아무 말 없이 아무 일도 안 하던 것**도 같이 고쳤다.
조용한 실패는 고장으로 읽힌다.

## 남겨 둔 것

- **저장할 때는 여전히 원본 PNG 다.** `MemoStore.saveImage` 가 줄이지도, JPEG 로 바꾸지도
  않는다(`CLAUDE.md` 의 "1024px 제한 · JPEG 0.7" 규칙과 어긋난 채로 있다).
  읽는 쪽을 다 고쳐서 이제 죽지는 않지만, 디스크와 iCloud 백업 용량은 그대로 크다.
  줄여서 저장하면 되돌릴 수 없으므로(화질 손실) 사람이 정할 일로 남긴다.
- `ClipKeyboard/Screens/List/ClipKeyboardList.swift` 의 목록 카드도 `loadImage` 를 쓴다.
  앱이라 한도에 안 걸릴 뿐, 같은 갈래다.

## 확인할 것

1. **큰 사진**(아이폰 카메라 원본, 12MP)을 단축어에 붙인다.
2. 키보드를 다른 앱에서 띄우고 그 키를 누른다 → 사진이 클립보드에 올라가야 한다.
3. 그 앱의 입력창을 길게 눌러 붙여넣는다 → 사진이 붙어야 한다.
4. 이미지 단축어를 **여러 개** 만들고 키보드를 오르내린다 → 키보드가 죽거나 깜빡이지 않아야 한다.
5. 글+사진 단축어를 **앱에서** 눌러 복사한다 → 사진과 글이 **둘 다** 붙을 수 있어야 한다.
