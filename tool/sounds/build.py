#!/usr/bin/env python3
"""Rebuild assets/sounds/*.wav and assets/sounds/CREDITS.md from CC0 freesound.org previews.

Needs python3 (standard library only) and ffmpeg on PATH. Run from anywhere:

    python3 tool/sounds/build.py                    # download, process, verify, write credits
    python3 tool/sounds/build.py --verify-licenses  # also re-check each sound page says CC0
    python3 tool/sounds/build.py --cache DIR        # keep raw previews in DIR

Raw previews are public HQ preview MP3s (no login, no API key). They are cached outside the
repo, checked against the SHA-256 below, and never executed. Requests are sequential and paced.
"""
import argparse
import hashlib
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
import wave

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets", "sounds")
USER_AGENT = "Mozilla/5.0 (compatible; sfx-build/1.0)"
CC0_LINK = "http://creativecommons.org/publicdomain/zero/1.0/"
PAUSE_SECONDS = 2.0
PEAK_CEILING_DB = -1.5

SOURCES = {
    "692828": dict(
        name="Woodblock-soft.wav",
        user="hollandm",
        preview="https://cdn.freesound.org/previews/692/692828_5309408-hq.mp3",
        sha256="037409e8a5fd3307b4cb630b43647c8f02e7120f53c529fa89a0144268f8942e",
    ),
    "534094": dict(
        name="clock-tick-01.flac",
        user="pbimal",
        preview="https://cdn.freesound.org/previews/534/534094_11830391-hq.mp3",
        sha256="8a46a0b0568dc5218ce8e4cfbb199c292573fbd6ca85f7cd0773ecbbbe7658db",
    ),
    "528561": dict(
        name="Soft UI Button Click",
        user="Jummit",
        preview="https://cdn.freesound.org/previews/528/528561_10360410-hq.mp3",
        sha256="6f7f5551bf02803ca25eccb134388281a1e00e2756faf412082f7dffc5abf22e",
    ),
    "528957": dict(
        name="Correct Answer / That's Right!",
        user="Beetlemuse",
        preview="https://cdn.freesound.org/previews/528/528957_10334845-hq.mp3",
        sha256="ec6fb53c6767cdb5dbaea5dd49417c32a010e665366cacceecdbca67475643fb",
    ),
    "449996": dict(
        name="whoosh_short_mid.wav",
        user="DJT4NN3R",
        preview="https://cdn.freesound.org/previews/449/449996_3217484-hq.mp3",
        sha256="0f19099f75fd3d07a7950b3f2448bdfb559605a1c05e0855f7cc15d6784002b9",
    ),
    "625174": dict(
        name="[UI Sound] Approval - High Pitched Bell Synth",
        user="GabFitzgerald",
        preview="https://cdn.freesound.org/previews/625/625174_13251199-hq.mp3",
        sha256="4cb74610d5834673c27fb14da64adf5cc3b956bf196d7b6feb6cdf4b9d9b4454",
    ),
    "69385": dict(
        name="doorbell2.wav",
        user="guitarguy1985",
        preview="https://cdn.freesound.org/previews/69/69385_533680-hq.mp3",
        sha256="af560bfdfc273e1220b74884050f61fb623cabca2552b8f471207f3b7beb029c",
    ),
    "610703": dict(
        name="Good answer harp glissando.wav",
        user="oggraphics",
        preview="https://cdn.freesound.org/previews/610/610703_7772719-hq.mp3",
        sha256="13db23dd6bd57ef60b6155dfc0406ff4f06b06c061ce18186eece8abe1839b33",
    ),
    "872227": dict(
        name="Soft Impact - Pillow Hit",
        user="KoimeMatsuchiya",
        preview="https://cdn.freesound.org/previews/872/872227_19256798-hq.mp3",
        sha256="244a081dd0e32e77559e8f0ce6adf5a01b694fb9ac6413a494d9c277924d9d5f",
    ),
}

# Per-cue recipe. Times are seconds in the final (post pitch-shift) clip, measured from the
# first sample above `gate` dBFS. `level` is the target K-weighted RMS in dBFS; the repeating
# ticks sit well below correct and times_up. `rate` > 1 raises pitch and shortens the clip.
# `span` is the allowed duration range in seconds and the build fails outside it. Pitched cues
# share one key (C major) so the countdown, start, correct, time-up and results cues agree.
CUES = [
    dict(file="correct.wav", src="528957", gate=-45, start=0.0, dur=0.56, fade_in=0.004, fade_out=0.10, hp=120, level=-15.5, span=(0.30, 0.70)),
    dict(file="pass.wav", src="449996", gate=-52, start=0.08, dur=0.30, fade_in=0.004, fade_out=0.12, hp=120, lp=7000, level=-20.5, span=(0.20, 0.45)),
    dict(file="start_shing.wav", src="625174", gate=-45, start=0.0, dur=0.80, fade_in=0.002, fade_out=0.30, hp=200, rate=2 ** (-9 / 12), level=-18.5, span=(0.40, 0.90)),
    dict(file="results_sparkle.wav", src="610703", gate=-50, start=0.0, dur=1.70, fade_in=0.004, fade_out=0.35, hp=150, level=-18.5, span=(0.80, 1.80)),
    dict(file="times_up.wav", src="69385", gate=-20, start=0.0, dur=1.55, fade_in=0.003, fade_out=0.55, hp=150, rate=2 ** (1 / 12), level=-16.5, span=(0.80, 1.60)),
    dict(file="whoomp.wav", src="872227", gate=-45, start=0.0, dur=0.24, fade_in=0.003, fade_out=0.10, hp=70, level=-22.8, span=(0.15, 0.45)),
    dict(file="tock.wav", src="692828", gate=-50, start=0.0, dur=0.10, fade_in=0.001, fade_out=0.04, hp=150, rate=2 ** (-1 / 12), level=-21.0, span=(0.03, 0.12)),
    dict(file="tock_hi.wav", src="692828", gate=-50, start=0.0, dur=0.085, fade_in=0.001, fade_out=0.035, hp=150, rate=2 ** (4 / 12), level=-20.5, span=(0.03, 0.12)),
    dict(file="tick.wav", src="534094", gate=-45, start=0.0, dur=0.11, fade_in=0.001, fade_out=0.045, hp=200, level=-23.0, span=(0.03, 0.12)),
    dict(file="urgency_tick.wav", src="534094", gate=-45, start=0.0, dur=0.09, fade_in=0.001, fade_out=0.04, hp=200, rate=2 ** (4 / 12), level=-21.5, span=(0.03, 0.12)),
    dict(file="ui_tick.wav", src="528561", gate=-50, start=0.0, dur=0.045, fade_in=0.001, fade_out=0.02, hp=200, level=-26.0, span=(0.03, 0.12)),
]


def find_ffmpeg():
    for candidate in (shutil.which("ffmpeg"), "/opt/homebrew/bin/ffmpeg"):
        if candidate and os.path.exists(candidate):
            return candidate
    sys.exit("ffmpeg not found")


FFMPEG = find_ffmpeg()


def run(args):
    return subprocess.run(args, check=True, capture_output=True, text=True)


def fetch(url, dest):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read()
    with open(dest, "wb") as handle:
        handle.write(data)


def sha256(path):
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()


def download_previews(cache, ignore_sha):
    needed = sorted({cue["src"] for cue in CUES})
    fetched = False
    for sid in needed:
        source = SOURCES[sid]
        path = os.path.join(cache, sid + ".mp3")
        if not os.path.exists(path):
            if fetched:
                time.sleep(PAUSE_SECONDS)
            print("download", sid, source["preview"])
            fetch(source["preview"], path)
            fetched = True
        digest = sha256(path)
        expected = source["sha256"]
        if expected and digest != expected and not ignore_sha:
            sys.exit("sha256 mismatch for %s: got %s, expected %s" % (sid, digest, expected))
        if not expected:
            print("sha256", sid, digest)


def verify_licenses():
    for index, sid in enumerate(sorted({cue["src"] for cue in CUES})):
        source = SOURCES[sid]
        if index:
            time.sleep(PAUSE_SECONDS)
        url = page_url(sid)
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=60) as response:
            page = response.read().decode("utf-8", "replace")
        link = re.search(r'href="([^"]*creativecommons\.org[^"]*)"[^>]*>\s*([^<]+?)\s*</a>', page)
        ok = bool(link) and link.group(1) == CC0_LINK and link.group(2) == "Creative Commons 0"
        print("license", sid, source["user"], "CC0 OK" if ok else "NOT CC0: %r" % (link.groups() if link else None))
        if not ok:
            sys.exit("license check failed for sound %s" % sid)


def page_url(sid):
    return "https://freesound.org/people/%s/sounds/%s/" % (SOURCES[sid]["user"], sid)


def shape_filter(cue):
    rate = cue.get("rate", 1.0)
    chain = ["aformat=channel_layouts=mono", "aresample=44100"]
    if rate != 1.0:
        chain += ["asetrate=%.4f" % (44100 * rate), "aresample=44100"]
    chain += [
        "silenceremove=start_periods=1:start_threshold=%ddB:start_silence=0.002:detection=peak" % cue["gate"],
        "atrim=start=%.4f:duration=%.4f" % (cue["start"], cue["dur"]),
        "asetpts=PTS-STARTPTS",
        "highpass=f=%d" % cue["hp"],
    ]
    if cue.get("lp"):
        chain.append("lowpass=f=%d" % cue["lp"])
    chain += [
        "afade=t=in:st=0:d=%.4f:curve=qsin" % cue["fade_in"],
        "afade=t=out:st=%.4f:d=%.4f:curve=qsin" % (cue["dur"] - cue["fade_out"], cue["fade_out"]),
    ]
    return ",".join(chain)


def volume_stats(path, prefilter=""):
    chain = (prefilter + "," if prefilter else "") + "volumedetect"
    result = run([FFMPEG, "-hide_banner", "-nostats", "-i", path, "-af", chain, "-f", "null", "-"])
    mean = re.search(r"mean_volume: (-?[\d.]+) dB", result.stderr)
    peak = re.search(r"max_volume: (-?[\d.]+) dB", result.stderr)
    return float(mean.group(1)), float(peak.group(1))


# Phone speakers drop out below ~150 Hz and the ear leans toward 2-4 kHz, so loudness is read
# through a high-pass and a high shelf (a cheap K-weighting) rather than from the raw RMS.
K_WEIGHT = "highpass=f=150,highshelf=f=1700:g=4"


def build_cue(cue, cache, scratch):
    shaped = os.path.join(scratch, cue["file"] + ".shaped.wav")
    run([FFMPEG, "-y", "-hide_banner", "-i", os.path.join(cache, cue["src"] + ".mp3"),
         "-af", shape_filter(cue), "-c:a", "pcm_f32le", shaped])
    k_mean, _ = volume_stats(shaped, K_WEIGHT)
    _, raw_peak = volume_stats(shaped)
    gain = cue["level"] - k_mean
    limited = raw_peak + gain > PEAK_CEILING_DB
    if limited:
        gain = PEAK_CEILING_DB - raw_peak
    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.join(OUT_DIR, cue["file"])
    run([FFMPEG, "-y", "-hide_banner", "-i", shaped,
         "-af", "volume=%.3fdB,aresample=44100:osf=s16:dither_method=triangular_hp" % gain,
         "-ac", "1", "-ar", "44100", "-c:a", "pcm_s16le", "-fflags", "+bitexact", "-flags:a", "+bitexact", out])
    return gain, limited


def describe(cue):
    steps = ["mono 44.1 kHz 16-bit", "leading silence removed", "cut to %.0f ms" % (cue["dur"] * 1000)]
    rate = cue.get("rate", 1.0)
    if rate != 1.0:
        semitones = round(12 * math.log2(rate))
        steps.append("pitched %s %d semitone%s by resampling" % ("up" if semitones > 0 else "down", abs(semitones), "" if abs(semitones) == 1 else "s"))
    steps.append("%.0f ms fade-out" % (cue["fade_out"] * 1000))
    steps.append("high-passed at %d Hz" % cue["hp"])
    if cue.get("lp"):
        steps.append("low-passed at %.0f kHz" % (cue["lp"] / 1000))
    steps.append("level-matched")
    return ", ".join(steps)


def verify(cue):
    path = os.path.join(OUT_DIR, cue["file"])
    with wave.open(path, "rb") as handle:
        channels, width, rate, frames = handle.getnchannels(), handle.getsampwidth(), handle.getframerate(), handle.getnframes()
    assert (channels, width, rate) == (1, 2, 44100), "%s is not 44.1 kHz mono Int16" % cue["file"]
    duration = frames / float(rate)
    low, high = cue["span"]
    assert low <= duration <= high, "%s lasts %.3f s, outside %.2f-%.2f s" % (cue["file"], duration, low, high)
    k_mean, _ = volume_stats(path, K_WEIGHT)
    _, peak = volume_stats(path)
    assert peak <= -1.0, "%s peaks at %.2f dBFS" % (cue["file"], peak)
    return duration, peak, k_mean, os.path.getsize(path)


def write_credits():
    lines = [
        "# Sound credits",
        "",
        "Every sound in this folder is a Creative Commons 0 (CC0 1.0 public domain dedication) recording from freesound.org. No attribution is required. The credits are listed anyway.",
        "",
        "Each sound page was checked to show the license \"Creative Commons 0\" linking to https://creativecommons.org/publicdomain/zero/1.0/. The files are rebuilt from the public HQ previews with `python3 tool/sounds/build.py`.",
        "",
        "| File | Freesound sound | Uploader | Page | License | Processing |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for cue in sorted(CUES, key=lambda item: item["file"]):
        source = SOURCES[cue["src"]]
        lines.append("| %s | %s | %s | %s | CC0 1.0 | %s |" % (
            cue["file"], source["name"], source["user"], page_url(cue["src"]), describe(cue)))
    lines.append("")
    with open(os.path.join(OUT_DIR, "CREDITS.md"), "w") as handle:
        handle.write("\n".join(lines))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--cache", help="directory for raw preview MP3s (default: a folder in the system temp dir)")
    parser.add_argument("--verify-licenses", action="store_true", help="fetch each sound page and require CC0")
    parser.add_argument("--ignore-sha", action="store_true", help="accept previews whose SHA-256 changed")
    args = parser.parse_args()

    cache = args.cache or os.path.join(tempfile.gettempdir(), "scripture_up_sound_previews")
    os.makedirs(cache, exist_ok=True)
    download_previews(cache, args.ignore_sha)
    if args.verify_licenses:
        verify_licenses()

    total = 0
    with tempfile.TemporaryDirectory() as scratch:
        print("%-20s %7s %8s %8s %6s  %s" % ("file", "secs", "peak", "k-rms", "bytes", "gain"))
        for cue in CUES:
            gain, limited = build_cue(cue, cache, scratch)
            duration, peak, k_mean, size = verify(cue)
            total += size
            print("%-20s %7.3f %8.2f %8.2f %6d  %+.1f dB%s" % (
                cue["file"], duration, peak, k_mean, size, gain, " (peak-limited)" if limited else ""))
    write_credits()
    print("total %.1f KB" % (total / 1024.0))


if __name__ == "__main__":
    main()
