from urllib.parse import urljoin, urlsplit, urlunsplit, parse_qsl, urlencode


class ImageExtractor:
    IMAGE_EXTS = {"jpg", "jpeg", "png", "webp", "gif", "avif"}
    RESIZE_PARAMS = {"width", "height", "w", "h", "resize", "crop", "size", "maxwidth", "maxheight"}
    SIGNATURE_PARAMS = {"sig", "signature", "s", "token", "hmac", "hash", "policy",
                        "x-amz-signature", "x-goog-signature"}
    JUNK_MARKERS = ("doubleclick", "feedburner", "/1x1", "pixel")

    def extract(self, entry) -> str | None:
        base = getattr(entry, "link", "")
        candidates = self._collect(entry)
        candidates = [c for c in candidates if self._is_image(c)]
        candidates = [c for c in candidates if not self._is_junk(c["url"])]
        if not candidates:
            return None
        best = self._pick(candidates)
        return self._normalize(best["url"], base)

    def _collect(self, entry) -> list[dict]:
        out = []
        # приоритет 0 — media:content (обычно оригинал в высоком разрешении)
        for m in getattr(entry, "media_content", []):
            url = m.get("url") or m.get("href")
            if url:
                out.append({
                    "url": url,
                    "type": m.get("type", ""),
                    "medium": m.get("medium", ""),
                    "w": int(m.get("width") or 0),
                    "h": int(m.get("height") or 0),
                    "priority": 0,
                })
        # приоритет 1 — enclosure (RSS 2.0); feedparser кладёт URL в 'href'
        for e in getattr(entry, "enclosures", []):
            url = e.get("href") or e.get("url")
            if url:
                out.append({
                    "url": url,
                    "type": e.get("type", ""),
                    "medium": "",
                    "w": 0,
                    "h": 0,
                    "priority": 1,
                })
        return out

    def _is_image(self, c: dict) -> bool:
        if c["type"].startswith("image/") or c["medium"] == "image":
            return True
        ext = urlsplit(c["url"]).path.lower().rsplit(".", 1)[-1]
        return ext in self.IMAGE_EXTS

    def _is_junk(self, url: str) -> bool:
        u = url.lower()
        return u.startswith("data:") or any(j in u for j in self.JUNK_MARKERS)

    def _pick(self, candidates: list[dict]) -> dict:
        # определение минимального сначала по источнику (media_content > enclosure), затем по объявленной площади картинки
        return min(candidates, key=lambda c: (c["priority"], -(c["w"] * c["h"])))

    def _normalize(self, url: str, base: str) -> str:
        url = urljoin(base, url)
        parts = urlsplit(url)
        path_ext = parts.path.lower().rsplit(".", 1)[-1]
        # снятие resize-параметров только если:
        # 1. путь кончается на расширение картинки, и
        # 2. в query нет подписи — иначе обрезанный URL станет невалидным (401)
        if path_ext in self.IMAGE_EXTS and parts.query:
            params = parse_qsl(parts.query)
            has_signature = any(k.lower() in self.SIGNATURE_PARAMS for k, _ in params)
            if not has_signature:
                kept = [(k, v) for k, v in params if k.lower() not in self.RESIZE_PARAMS]
                url = urlunsplit(parts._replace(query=urlencode(kept)))
        return url