---
name: demo-voiceover
description: >
  Write and generate the narration for a demo or product video and lay it over
  the cut. Covers how to write marketing narration that explains the use case
  instead of describing the screen, generating it in Joe's cloned ElevenLabs
  voice as one continuous eleven_v4 take, splitting that take at the real pauses
  between scenes, holding each scene until its line ends, levelling the mix and
  checking the audio without being able to hear it. Ships voiceover_take.py,
  lay_narration.py and an example narration file. Triggers on: "voiceover",
  "narration", "narrate the demo", "add a voice track", "ElevenLabs", "use my
  voice", "text to speech for a video", "talk track", "VO script".
metadata:
  tags: demo, voiceover, narration, elevenlabs, tts, ffmpeg, audio
---

# demo-voiceover: narration for demo videos

This skill picks up once the picture is cut. It covers the script, the voice
and the mix. The recorders live in **vhs-demos**, **playwright-demos** and
**demo-media**. For narration inside a Remotion composition see the vendored
`remotion-best-practices/rules/voiceover.md` instead.

Everything here comes from the October 2026 "Skyflow for Amazon Bedrock
AgentCore Gateway" launch video. Joe called the result "so much better" than
the earlier per-scene version.

## 1. Write the narration

Joe rewrote the first draft along these lines. Start from them.

1. **Explain the use case and its value instead of the screen.** The viewer can
   see what is on screen. The narration says why it matters in general terms.
   For example say "retrieving sensitive documents exposes regulated data to
   the agent" instead of "here is the case file in S3".
2. **Treat the on-screen data as an example.** Do not tell one fictional
   customer's story or name the example company in the voiceover.
3. **Be conversational and end like a person talking.** "Together, Skyflow and
   AgentCore Gateway keep your private data private and your agents
   productive" beat a billboard of fragments such as "Same agent. Same tools."
4. **Read it aloud in your head.** Stacked "and"s and sentences with two
   "when" clauses both sounded wrong to Joe.
5. **Check every technical claim.** "Skyflow runs inside the gateway" was
   wrong because the interceptor is a Lambda function attached to the gateway.
   "Plugs into" was right. On-screen titles need the same check.
6. **Budget about 150 spoken words a minute.** `eleven_v4` read 154 words in
   63.7 seconds including its pauses. Let the narration set each scene's length
   rather than squeezing words into a fixed cut.

Keep the script in the demoed project with the scene timings, the on-screen
text and a word count per scene. That is what the reviewer marks up.

## 2. Generate it in one take

```bash
export ELEVENLABS_API_KEY=...                 # never commit it
python3 voiceover_take.py narration.json demo-out/audio/v4
```

`narration.json` follows `narration.example.json` beside this script. The
script sends every segment as one text with paragraph breaks between them to
the `with-timestamps` endpoint. It saves `take.mp3` and `alignment.json`. Then
it writes one clip per segment, cut inside the silence between segments.

1. **Model.** Use `eleven_v4`. It is the current flagship and clearly beat
   `eleven_multilingual_v2` for this voice. The full list is on the
   [ElevenLabs models page](https://elevenlabs.io/docs/overview/models).
2. **Voice.** Joe's instant clone is named "Joe from Skyflow" and its id is
   `71bqcK8h3htKuzFJdsMa`. It is Joe's own voice, so use it only for demos Joe
   asks for. Set `ELEVENLABS_VOICE_ID` to use another voice without editing
   the file.
3. **Settings that worked.** Stability 0.5, similarity 0.8, style 0.15, speaker
   boost on and speed 1.05.
4. **One take instead of one request per scene.** Separate requests start every
   clip cold. Even with `previous_text` and `next_text` one clip came back
   starting mid-sound with its first sample already at -28 dBFS.
5. **Regenerate the whole take** when one line changes. The flow across scene
   boundaries is the reason the single take sounds natural.

### Gotchas

1. **The timestamps run late.** Each segment's reported end fell about 0.4
   seconds after the audio actually went quiet. Cutting halfway between the
   reported end and the next start clipped the start of the next line. The
   script finds the longest silent run near each boundary and cuts inside it.
2. **Output formats are tier-gated.** `mp3_44100_192` needs the Creator tier.
   The default `mp3_44100_128` works on every plan.
3. **The API key may not list models.** A key without `models_read` gets 403
   from `/v1/models`. Read the models page instead.

## 3. Lay it over the cut

Place each clip at its scene's start plus a short lead and hold the scene's
last frame until the clip ends plus a tail. These values gave even pauses of
1.2 to 2.2 seconds between lines.

| Setting | Value | Why |
|---|---|---|
| Lead | 0.5 s | The line starts as the new scene settles. |
| First line lead | 1.5 s | At 0.5 s the opening felt abrupt over the intro card's fade-in. |
| Tail | 0.7 s | The picture breathes before the next cut. |
| Minimum scene length | Only what the picture needs | Long minimums left four seconds of dead air. |

```bash
python3 lay_narration.py cut.mp4 narrated.mp4 1.5:intro.mp3 6.4:diagram.mp3 20.1:before.mp3
```

`lay_narration.py` copies the picture untouched, gives every clip a 20 ms
fade-in and normalises the mix to -16 LUFS with a -1.5 dBTP ceiling.

## 4. Check it without ears

The agent cannot hear audio. Measure it and then ask the person to listen for
named spots.

```bash
# Where the speech and the gaps are
ffmpeg -hide_banner -nostats -i narrated.mp4 -af silencedetect=n=-45dB:d=0.4 -f null - 2>&1 | grep silence_
# Integrated loudness, which should read about -16 LUFS
ffmpeg -hide_banner -nostats -i narrated.mp4 -af ebur128 -f null - 2>&1 | grep -A3 Summary
```

1. **Check every clip's first and last 30 ms.** Anything louder than about
   -60 dBFS at the very first sample means the clip starts mid-sound.
2. **Compare the gaps.** A gap longer than about 2.5 seconds reads as dead air.
3. **Ask the person to listen** for product names, hyphenated words such as
   "de-identifies" and any aside set off by dashes. Name the exact spots.
