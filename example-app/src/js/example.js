import { CapacitorFFmpeg } from '@capgo/capacitor-ffmpeg';

window.testEcho = () => {
    const inputValue = document.getElementById("echoInput").value;
    CapacitorFFmpeg.echo({ value: inputValue })
}
