import { common } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';

const FILE_NAME: string = 'lakeside-notes.json';
const EMPTY_TEXT: string = '沙箱里没有可读数据';
const BROKEN_TEXT: string = '笔记已无法阅读';
const GLYPHS: string = '¤§±µ¶ÆØÞßðþ';
const CONTEXT_RETRY_LIMIT: number = 20;
const CONTEXT_RETRY_MS: number = 50;

class SandboxNote {
  title: string = '';
  body: string = '';
}

@Entry
@Component
struct TrophyView {
  @State private notes: SandboxNote[] = [];
  @State private empty: boolean = false;
  @State private ready: boolean = false;
  private alive: boolean = true;
  private contextTries: number = 0;
  private retryId: number = -1;

  aboutToAppear(): void {
    this.alive = true;
    this.contextTries = 0;
    this.readSandbox();
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.cancelRetry();
  }

  build() {
    Scroll() {
      Column() {
        if (this.ready) {
          Text(BROKEN_TEXT)
            .width('100%')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A1A')
            .margin({ top: 24, bottom: 16 })
            .padding({ left: 16, right: 16 })
          if (this.empty) {
            Text(EMPTY_TEXT)
              .width('100%')
              .fontSize(16)
              .fontColor('#666666')
              .padding({ left: 16, right: 16 })
          }
          ForEach(this.notes, (item: SandboxNote, index: number) => {
            Column() {
              Text(garble(item.title))
                .width('100%')
                .fontSize(18)
                .fontColor('#1A1A1A')
              Text(garble(item.body))
                .width('100%')
                .fontSize(16)
                .fontColor('#333333')
                .margin({ top: 4 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(12)
            .margin({ left: 16, right: 16, bottom: 8 })
            .borderRadius(8)
            .backgroundColor('#F5F5F5')
          }, (item: SandboxNote, index: number) => index.toString() + item.title + item.body)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .backgroundColor('#FFFFFF')
  }

  private readSandbox(): void {
    if (!this.alive) {
      return;
    }
    let host = this.getUIContext().getHostContext();
    if (host === undefined) {
      this.scheduleRetry();
      return;
    }
    this.cancelRetry();
    this.contextTries = 0;
    let ctx = host as common.UIAbilityContext;
    let parsed = this.readFile(ctx.filesDir + '/' + FILE_NAME);
    if (!this.alive) {
      return;
    }
    this.notes = parsed.notes;
    this.empty = parsed.notes.length === 0;
    this.ready = true;
  }

  private readFile(path: string): SandboxRead {
    let result = new SandboxRead();
    if (!this.fileExists(path)) {
      return result;
    }
    let text = '';
    try {
      text = fs.readTextSync(path).trim();
    } catch (err) {
      return result;
    }
    if (text.length === 0) {
      return result;
    }
    try {
      let raw = JSON.parse(text) as Object[];
      if (!Array.isArray(raw)) {
        return result;
      }
      for (let i = 0; i < raw.length; i++) {
        let note = this.copyNote(raw[i] as SandboxNote);
        if (note !== undefined) {
          result.notes.push(note);
        }
      }
    } catch (err) {
      result.notes = [];
      return result;
    }
    return result;
  }

  private copyNote(raw: SandboxNote): SandboxNote | undefined {
    try {
      if (typeof raw !== 'object') {
        return undefined;
      }
      if (typeof raw.title !== 'string' || typeof raw.body !== 'string') {
        return undefined;
      }
      let note = new SandboxNote();
      note.title = raw.title;
      note.body = raw.body;
      return note;
    } catch (err) {
      return undefined;
    }
  }

  private fileExists(path: string): boolean {
    try {
      return fs.accessSync(path);
    } catch (err) {
      return false;
    }
  }

  private scheduleRetry(): void {
    if (!this.alive || this.contextTries >= CONTEXT_RETRY_LIMIT) {
      return;
    }
    this.contextTries++;
    this.cancelRetry();
    this.retryId = setTimeout(() => {
      this.retryId = -1;
      this.readSandbox();
    }, CONTEXT_RETRY_MS);
  }

  private cancelRetry(): void {
    if (this.retryId < 0) {
      return;
    }
    clearTimeout(this.retryId);
    this.retryId = -1;
  }
}

class SandboxRead {
  notes: SandboxNote[] = [];
}

function garble(text: string): string {
  if (text.length === 0) {
    return '¤¤¤';
  }
  let out = '';
  for (let i = 0; i < text.length; i++) {
    let code = text.charCodeAt(i);
    out += GLYPHS.charAt((code + i) % GLYPHS.length);
  }
  return out;
}
