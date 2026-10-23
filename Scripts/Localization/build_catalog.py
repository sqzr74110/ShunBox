from pathlib import Path
import json,re,subprocess
root=Path(__file__).resolve().parents[2]
rows={}
for line in (Path(__file__).parent/'translations.tsv').read_text().splitlines():
 if not line:continue
 parts=line.split('|');assert len(parts)==3,line
 key,en,ja=[x.replace('\\n','\n') for x in parts];rows[key]={'en':en,'ja':ja,'zh-Hans':key}
# Use Foundation's deterministic Chinese transliteration, then allow editorial overrides.
payload=json.dumps(list(rows),ensure_ascii=False)
Path('/tmp/shunbox-hans.json').write_text(payload)
script='''import Foundation
let keys = try JSONDecoder().decode([String].self, from: Data(contentsOf: URL(fileURLWithPath: "/tmp/shunbox-hans.json")))
let result = keys.map { $0.applyingTransform(StringTransform("Hans-Hant"), reverse: false) ?? $0 }
try JSONEncoder().encode(result).write(to: URL(fileURLWithPath: "/tmp/shunbox-hant.json"))
'''
Path('/tmp/shunbox-hant.swift').write_text(script)
subprocess.run(['swift','-module-cache-path','/tmp/shuntools-swift-cache','/tmp/shunbox-hant.swift'],check=True)
for key,value in zip(rows,json.loads(Path('/tmp/shunbox-hant.json').read_text())):rows[key]['zh-Hant']=value
extras=json.loads((Path(__file__).parent/'additional.json').read_text())
for key,values in extras.items():
 rows[key.replace('\\n','\n')].update({code:value.replace('\\n','\n') for code,value in values.items()})
strings={key:{'extractionState':'manual','localizations':{code:{'stringUnit':{'state':'translated','value':value}} for code,value in values.items()}} for key,values in rows.items()}
# Native intent metadata is localized by the system, independently of the in-app picker.
intents={
'Tool':('工具','ツール'), 'Image Studio':('图片工坊','画像工房'),'Ringtone Maker':('铃声制作','着信音作成'),'Device Info':('设备信息','端末情報'),'Device Check':('设备自检','端末セルフチェック'),'QR Code':('二维码','QRコード'),'PDF Organizer':('PDF 整理','PDF整理'),'Open Tool':('打开工具','ツールを開く'),'Convert Image':('转换图片','画像を変換'),'Generate QR Code':('生成二维码','QRコードを生成'),'Image Format':('图片格式','画像形式'),'Image':('图片','画像'),'Text or URL':('文字或链接','テキストまたはURL'),
'Open ${tool}':('打开${tool}','${tool}を開く'),'Convert ${image} to ${format}':('将${image}转换为${format}','${image}を${format}に変換'),'Create a QR code from ${text}':('从${text}生成二维码','${text}からQRコードを生成'),
'Open a ShunBox tool. Files are selected only by you.':('打开顺匣工具，文件仅由你选择。','順匣のツールを開きます。ファイルは自分で選択します。'),
'Convert an image on-device and remove source metadata. Returns a file; does not overwrite the original.':('在本机转换图片并移除原始元数据。返回新文件，不覆盖原图。','端末内で画像を変換し、元のメタデータを削除します。新しいファイルを返し、元画像を上書きしません。'),
'Create a QR image from text or a URL, entirely on-device.':('在本机将文字或链接生成为二维码图片。','端末内でテキストやURLからQRコード画像を作ります。')}
for key,(zh,ja) in intents.items():
 strings[key]={'extractionState':'manual','localizations':{code:{'stringUnit':{'state':'translated','value':value}} for code,value in {'en':key,'zh-Hans':zh,'zh-Hant':rows.get(zh,{}).get('zh-Hant',zh),'ja':ja}.items()}}
for key,(zh,ja) in intents.items():
 for code in ['ko','fr','de','es','pt-BR']:
  value=rows.get(zh,{}).get(code,key)
  strings[key]['localizations'][code]={'stringUnit':{'state':'translated','value':value}}

metadata_extra = {
 'Open Tool': ['도구 열기','Ouvrir un outil','Werkzeug öffnen','Abrir herramienta','Abrir ferramenta'],
 'Convert Image': ['이미지 변환','Convertir une image','Bild konvertieren','Convertir imagen','Converter imagem'],
 'Image Format': ['이미지 형식','Format d’image','Bildformat','Formato de imagen','Formato da imagem'],
 'Open ${tool}': ['${tool} 열기','Ouvrir ${tool}','${tool} öffnen','Abrir ${tool}','Abrir ${tool}'],
 'Convert ${image} to ${format}': ['${image}를 ${format}로 변환','Convertir ${image} en ${format}','${image} zu ${format} konvertieren','Convertir ${image} a ${format}','Converter ${image} para ${format}'],
 'Create a QR code from ${text}': ['${text}로 QR 코드 생성','Créer un QR à partir de ${text}','QR-Code aus ${text} erstellen','Crear QR de ${text}','Criar QR de ${text}'],
 'Open a ShunBox tool. Files are selected only by you.': ['ShunBox 도구를 엽니다. 파일은 직접 선택합니다.','Ouvre un outil ShunBox. Vous choisissez les fichiers.','Öffnet ein ShunBox-Werkzeug. Dateien wählst du selbst.','Abre una herramienta ShunBox. Tú eliges los archivos.','Abre uma ferramenta ShunBox. Você escolhe os arquivos.'],
 'Convert an image on-device and remove source metadata. Returns a file; does not overwrite the original.': ['기기에서 이미지를 변환하고 메타데이터를 지웁니다. 원본을 덮어쓰지 않고 새 파일을 반환합니다.','Convertit localement sans métadonnées. Renvoie un fichier sans écraser l’original.','Konvertiert lokal ohne Quellmetadaten. Gibt eine Datei zurück, Original unverändert.','Convierte localmente sin metadatos. Devuelve un archivo sin sobrescribir el original.','Converte localmente sem metadados. Retorna um arquivo sem substituir o original.'],
 'Create a QR image from text or a URL, entirely on-device.': ['기기에서 텍스트나 URL의 QR 이미지를 만듭니다.','Crée une image QR à partir de texte ou d’une URL, localement.','Erstellt ein QR-Bild aus Text oder URL, vollständig lokal.','Crea una imagen QR de texto o URL, en el dispositivo.','Cria uma imagem QR de texto ou URL, no dispositivo.']
}
for key,values in metadata_extra.items():
 for code,value in zip(['ko','fr','de','es','pt-BR'],values):
  strings[key]['localizations'][code]={'stringUnit':{'state':'translated','value':value}}

(root/'ShunTools/Resources/Localizable.xcstrings').write_text(json.dumps({'sourceLanguage':'zh-Hans','strings':strings,'version':'1.0'},ensure_ascii=False,indent=2))
# Privacy purpose strings and app name follow the device/app language chosen in iOS Settings.
for code in ['zh-Hans','zh-Hant','en','ja','ko','fr','de','es','pt-BR']:
 folder=root/'ShunTools/Resources'/f'{code}.lproj';folder.mkdir(exist_ok=True)
 d={'CFBundleDisplayName':rows['顺匣'][code],'NSPhotoLibraryAddUsageDescription':rows['将处理后的图片保存到你的相册。'][code],'NSMicrophoneUsageDescription':rows['仅在你开始麦克风自检时录音，用于本机回放。'][code]}
 (folder/'InfoPlist.strings').write_text('\n'.join(json.dumps(k,ensure_ascii=False)+' = '+json.dumps(v,ensure_ascii=False)+';' for k,v in d.items()))
print(f'{len(strings)} localized entries')
