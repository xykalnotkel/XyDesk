/** Video dan audio remote diputar terpisah; audio yang tidak mengalir tidak
 * ikut menjadi track pada elemen video. Tidak menghentikan track milik peer. */
export function videoOnlyStream(stream: MediaStream): MediaStream {
  return new MediaStream(stream.getVideoTracks());
}

export async function playRemoteVideo(video: HTMLVideoElement, stream: MediaStream): Promise<void> {
  video.muted = true;
  video.playsInline = true;
  if (video.srcObject !== stream) video.srcObject = stream;
  await video.play();
}
