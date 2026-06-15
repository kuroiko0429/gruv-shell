#!/usr/bin/env python3
import urllib.request
import json
import sys
import os
import subprocess

def get_active_wifi_ssid():
    try:
        # Run nmcli to get the active wifi SSID
        res = subprocess.check_output(
            ["nmcli", "-t", "-f", "ACTIVE,SSID", "dev", "wifi"], 
            text=True, 
            timeout=3
        )
        for line in res.splitlines():
            if line.startswith("yes:"):
                return line.split(":", 1)[1].strip()
    except Exception:
        pass
    return None

def get_weather():
    try:
        # Load configuration file
        script_dir = os.path.dirname(os.path.abspath(__file__))
        config_path = os.path.join(script_dir, "weather_config.json")
        
        config = {
            "use_ip_geolocation": False,
            "default_location": {
                "city": "江別市, 北海道",
                "lat": 43.1081,
                "lon": 141.5506
            },
            "wifi_locations": {}
        }
        
        if os.path.exists(config_path):
            with open(config_path, "r", encoding="utf-8") as f:
                try:
                    config.update(json.load(f))
                except Exception as e:
                    sys.stderr.write(f"[Weather] Failed to parse config JSON: {e}\n")
        
        lat, lon, city = None, None, None
        
        # 1. Try Wi-Fi SSID mapping first
        active_ssid = get_active_wifi_ssid()
        if active_ssid and active_ssid in config.get("wifi_locations", {}):
            loc = config["wifi_locations"][active_ssid]
            city = loc.get("city", "江別市, 北海道")
            lat = loc.get("lat")
            lon = loc.get("lon")
            sys.stderr.write(f"[Weather] Resolved location from Wi-Fi SSID ({active_ssid}): {city} ({lat}, {lon})\n")
        
        # 2. Try IP geolocation if enabled
        if (lat is None or lon is None) and config.get("use_ip_geolocation", False):
            try:
                req = urllib.request.Request(
                    "http://ip-api.com/json/", 
                    headers={'User-Agent': 'Mozilla/5.0'}
                )
                with urllib.request.urlopen(req, timeout=5) as r:
                    geo = json.loads(r.read().decode('utf-8'))
                lat = geo.get('lat')
                lon = geo.get('lon')
                city = f"{geo.get('city', 'Tokyo')}, {geo.get('countryCode', 'JP')}"
                sys.stderr.write(f"[Weather] Resolved location from IP geolocation: {city} ({lat}, {lon})\n")
            except Exception as e:
                sys.stderr.write(f"[Weather] IP Geolocation failed: {e}\n")
        
        # 3. Fallback to default location
        if lat is None or lon is None:
            loc = config.get("default_location", {})
            city = loc.get("city", "江別市, 北海道")
            lat = loc.get("lat", 43.1081)
            lon = loc.get("lon", 141.5506)
            sys.stderr.write(f"[Weather] Resolved location from default config: {city} ({lat}, {lon})\n")
        
        # Get weather from Open-Meteo
        url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,weather_code,is_day"
        req_w = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req_w, timeout=5) as r:
            wdata = json.loads(r.read().decode('utf-8'))
        
        current = wdata.get('current', {})
        temp = current.get('temperature_2m', 0.0)
        code = current.get('weather_code', 0)
        is_day = current.get('is_day', 1)
        
        # Map WMO weather codes to Nerd Font glyphs and Japanese descriptions
        weather_map = {
            0: ("晴れ", "󰖙" if is_day else "󰖔"),
            1: ("おおむね晴れ", "󰖕" if is_day else "󰖔"),
            2: ("晴れのち曇り", "󰖕" if is_day else "󰖔"),
            3: ("曇り", "󰖐"),
            45: ("霧", "󰖑"),
            48: ("沈着霧", "󰖑"),
            51: ("弱い霧雨", "󰖗"),
            53: ("霧雨", "󰖗"),
            55: ("強い霧雨", "󰖗"),
            61: ("弱い雨", "󰖖"),
            63: ("雨", "󰖖"),
            65: ("強い雨", "󰖖"),
            71: ("弱い雪", "󰖘"),
            73: ("雪", "󰖘"),
            75: ("強い雪", "󰖘"),
            77: ("細氷", "󰖘"),
            80: ("弱い俄か雨", "󰖖"),
            81: ("俄か雨", "󰖖"),
            82: ("強い俄か雨", "󰖖"),
            85: ("弱い俄か雪", "󰖘"),
            86: ("強い俄か雪", "󰖘"),
            95: ("雷雨", "󰖓"),
        }
        desc, emoji = weather_map.get(code, ("不明", "󰖚"))
        return {
            "city": city,
            "temp": temp,
            "desc": desc,
            "emoji": emoji,
            "code": code
        }
    except Exception as e:
        sys.stderr.write(f"[Weather] Fetcher error: {e}\n")
        sys.stderr.flush()
        return {
            "city": "Unknown",
            "temp": 0.0,
            "desc": "接続エラー",
            "emoji": "󰅠",
            "code": -1
        }

def main():
    print(json.dumps(get_weather()))

if __name__ == '__main__':
    main()
