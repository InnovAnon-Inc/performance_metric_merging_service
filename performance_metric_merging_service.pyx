# performance_metric_merging_service.py
# handles -march= / -mtune= architecture-specific distribution

import os
import shutil
import subprocess
from fastapi import FastAPI, BackgroundTasks, UploadFile, Header, HTTPException
from typing import Optional

app = FastAPI()

# Configuration: Where profiles live
# This should be the RW volume mounted for this service
BASE_PROFILE_DIR = os.getenv("PROFILE_DIR", "/var/lib/chimera/profiles")
GOLDEN_DIR = os.path.join(BASE_PROFILE_DIR, "golden")
STAGING_DIR = os.path.join(BASE_PROFILE_DIR, "staging")

# Ensure directories exist
for d in [GOLDEN_DIR, STAGING_DIR]:
    os.makedirs(d, exist_ok=True)

def merge_profiles(package: str, arch: str, compiler: str):
    """The 'Intense' logic. Merges staging files into the golden file."""
    pkg_staging = os.path.join(STAGING_DIR, arch, package)
    golden_file = os.path.join(GOLDEN_DIR, arch, f"{package}.afdo")
    os.makedirs(os.path.dirname(golden_file), exist_ok=True)

    files = [os.path.join(pkg_staging, f) for f in os.listdir(pkg_staging)]
    if not files:
        return

    try:
        if compiler == "clang":
            # llvm-profdata merge -o golden.afdo file1 file2 ...
            subprocess.run([
                "llvm-profdata", "merge", "-o", golden_file, *files
            ], check=True)
        else:
            # gcc-specific merge (simplified for MVP)
            # Note: gcov-tool merge usually works on directories
            subprocess.run([
                "gcov-tool", "merge", pkg_staging, "-o", golden_file
            ], check=True)
        
        print(f"✅ Merged {len(files)} profiles for {package} [{arch}]")
    except Exception as e:
        print(f"❌ Merge failed for {package}: {e}")

@app.post("/submit/{package}")
async def submit_profile(
    package: str,
    file: UploadFile,
    background_tasks: BackgroundTasks,
    x_arch: str = Header("amd64"),
    x_compiler: str = Header("gcc")
):
    # 1. Save to staging: staging/amd64/zlib/system_unique_id.afdo
    # Using filename as a crude unique ID for now
    save_path = os.path.join(STAGING_DIR, x_arch, package, file.filename)
    os.makedirs(os.path.dirname(save_path), exist_ok=True)

    with open(save_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # 2. Trigger merge in background
    background_tasks.add_task(merge_profiles, package, x_arch, x_compiler)

    return {"status": "received", "path": save_path}

