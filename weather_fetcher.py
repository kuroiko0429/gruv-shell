#!/usr/bin/env python3
import urllib.request
import json
import sys

def get_weather():
    try:
        # Get coordinates and country code from IP
        req = urllib.request.Request(
            "http://ip-api.com/json/", 
            headers={'User-Agent': 'Mozilla/5.0'}
        )
        with urllib.request.urlopen(req, timeout=5) as r:
            geo = json.loads(r.read().decode('utf-8'))
        lat = geo.get('lat', 35.6895)
        lon = geo.get('lon', 139.6917)
        city = geo.get('city', 'Tokyo')
        country_code = geo.get('countryCode', 'JP')
        location_str = f"{city}, {country_code}"
        
        # Get weather from Open-Meteo
        url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,weather_code,is_day"
        req_w = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req_w, timeout=5) as r:
            wdata = json.loads(r.read().decode('utf-8'))
        
        current = wdata.get('current', {})
        temp = current.get('temperature_2m', 0.0)
        code = current.get('weather_code', 0)
        is_day = current.get('is_day', 1)
        
        # Map WMO weather codes to emoji and Japanese descriptions
        weather_map = {
            0: ("晴れ", "☀️" if is_day else "🌙"),
            1: ("おおむね晴れ", "🌤️" if is_day else "🌙"),
            2: ("晴れのち曇り", "⛅" if is_day else "🌙"),
            3: ("曇り", "☁️"),
            45: ("霧", "🌫️"),
            48: ("沈着霧", "🌫️"),
            51: ("弱い霧雨", "🌦️"),
            53: ("霧雨", "🌦️"),
            55: ("強い霧雨", "🌦️"),
            61: ("弱い雨", "🌧️"),
            63: ("雨", "🌧️"),
            65: ("強い雨", "🌧️"),
            71: ("弱い雪", "❄️"),
            73: ("雪", "❄️"),
            75: ("強い雪", "❄️"),
            77: ("細氷", "❄️"),
            80: ("弱い俄か雨", "🌦️"),
            81: ("俄か雨", "🌦️"),
            82: ("強い俄か雨", "🌧️"),
            85: ("弱い俄か雪", "🌨️"),
            86: ("強い俄か雪", "🌨️"),
            95: ("雷雨", "⛈️"),
        }
        desc, emoji = weather_map.get(code, ("不明", "❓"))
        return {
            "city": location_str,
            "temp": temp,
            "desc": desc,
            "emoji": emoji,
            "code": code
        }
    except Exception as e:
        import sys
        sys.stderr.write(f"[Weather] Fetcher error: {e}\n")
        sys.stderr.flush()
        return {
            "city": "Unknown",
            "temp": 0.0,
            "desc": "接続エラー",
            "emoji": "⚠️",
            "code": -1
        }

def main():
    print(json.dumps(get_weather()))

if __name__ == '__main__':
    main()
