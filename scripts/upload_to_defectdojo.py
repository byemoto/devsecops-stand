#!/usr/bin/env python3
"""
Upload security scan results to DefectDojo
Usage: python upload_to_defectdojo.py
"""

import os
import sys
import json
import requests
from datetime import date

# ============================================================
# CONFIG — можно переопределить через переменные окружения
# ============================================================
DD_URL = os.getenv("DD_URL", "http://host.docker.internal:8743")
DD_API_KEY = os.getenv("DD_API_KEY", "")
DD_PRODUCT_NAME = os.getenv("DD_PRODUCT_NAME", "vulnerable-app")
DD_ENGAGEMENT_NAME = os.getenv("DD_ENGAGEMENT_NAME", f"CI Scan {date.today()}")
COMMIT_SHA = os.getenv("CI_COMMIT_SHA", "unknown")
BRANCH = os.getenv("CI_COMMIT_BRANCH", "main")

HEADERS = {
    "Authorization": f"Token {DD_API_KEY}",
}


def get_or_create_product():
    """Получить или создать продукт в DefectDojo"""
    r = requests.get(
        f"{DD_URL}/api/v2/products/",
        headers=HEADERS,
        params={"name": DD_PRODUCT_NAME}
    )
    r.raise_for_status()
    results = r.json()["results"]
    
    if results:
        product_id = results[0]["id"]
        print(f"[*] Product found: {DD_PRODUCT_NAME} (id={product_id})")
        return product_id
    
    # Создать новый продукт
    r = requests.post(
        f"{DD_URL}/api/v2/products/",
        headers=HEADERS,
        json={
            "name": DD_PRODUCT_NAME,
            "description": "DevSecOps portfolio stand — vulnerable app",
            "prod_type": 1
        }
    )
    r.raise_for_status()
    product_id = r.json()["id"]
    print(f"[+] Product created: {DD_PRODUCT_NAME} (id={product_id})")
    return product_id


def get_or_create_engagement(product_id):
    """Получить или создать engagement"""
    r = requests.get(
        f"{DD_URL}/api/v2/engagements/",
        headers=HEADERS,
        params={"name": DD_ENGAGEMENT_NAME, "product": product_id}
    )
    r.raise_for_status()
    results = r.json()["results"]
    
    if results:
        eng_id = results[0]["id"]
        print(f"[*] Engagement found: {DD_ENGAGEMENT_NAME} (id={eng_id})")
        return eng_id
    
    # Создать новый engagement
    today = str(date.today())
    r = requests.post(
        f"{DD_URL}/api/v2/engagements/",
        headers=HEADERS,
        json={
            "name": DD_ENGAGEMENT_NAME,
            "product": product_id,
            "target_start": today,
            "target_end": today,
            "status": "In Progress",
            "engagement_type": "CI/CD",
            "branch_tag": BRANCH,
            "commit_hash": COMMIT_SHA,
        }
    )
    r.raise_for_status()
    eng_id = r.json()["id"]
    print(f"[+] Engagement created: {DD_ENGAGEMENT_NAME} (id={eng_id})")
    return eng_id


def upload_scan(engagement_id, scan_type, file_path):
    """Загрузить результаты сканирования"""
    if not os.path.exists(file_path):
        print(f"[!] File not found: {file_path}, skipping")
        return
    
    with open(file_path, "rb") as f:
        r = requests.post(
            f"{DD_URL}/api/v2/import-scan/",
            headers=HEADERS,
            data={
                "engagement": engagement_id,
                "scan_type": scan_type,
                "active": True,
                "verified": False,
                "close_old_findings": False,
                "minimum_severity": "Info",
            },
            files={"file": (os.path.basename(file_path), f, "application/json")}
        )
    
    if r.status_code in (200, 201):
        result = r.json()
        print(f"[+] Uploaded {scan_type}: {result.get('test', {})}")
    else:
        print(f"[!] Failed to upload {scan_type}: {r.status_code} {r.text}")


def main():
    if not DD_API_KEY:
        print("[!] DD_API_KEY not set, skipping DefectDojo upload")
        sys.exit(0)
    
    print(f"[*] Connecting to DefectDojo: {DD_URL}")
    
    try:
        product_id = get_or_create_product()
        engagement_id = get_or_create_engagement(product_id)
        
        # Загрузить результаты сканирований
        upload_scan(engagement_id, "Gitleaks Scan", "gitleaks.json")
        upload_scan(engagement_id, "Semgrep JSON Report", "semgrep.json")
        
        print(f"\n[+] Done! View results at: {DD_URL}/engagement/{engagement_id}/")
    
    except requests.exceptions.ConnectionError:
        print(f"[!] Cannot connect to DefectDojo at {DD_URL}")
        sys.exit(1)
    except Exception as e:
        print(f"[!] Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()