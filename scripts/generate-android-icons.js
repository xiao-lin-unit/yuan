// Generate Android launcher icons from a source image.
// Usage: node scripts/generate-android-icons.js
// Source: resources/app_logo.png
import sharp from 'sharp'
import path from 'path'
import { fileURLToPath } from 'url'
import fs from 'fs'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const ROOT = path.resolve(__dirname, '..')

const SOURCE = path.join(ROOT, 'resources', 'app_logo.png')
const RES_DIR = path.join(ROOT, 'android', 'app', 'src', 'main', 'res')

// Android launcher icon sizes (legacy)
const ICON_SIZES = {
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
}

// Adaptive icon foreground sizes (full bleed, 108dp base)
const FOREGROUND_SIZES = {
  'mipmap-mdpi': 108,
  'mipmap-hdpi': 162,
  'mipmap-xhdpi': 216,
  'mipmap-xxhdpi': 324,
  'mipmap-xxxhdpi': 432,
}

// Splash / background color (white to match the logo background)
const BG_COLOR = { r: 255, g: 255, b: 255, alpha: 1 }

async function generateIcons() {
  if (!fs.existsSync(SOURCE)) {
    console.error(`Source image not found: ${SOURCE}`)
    process.exit(1)
  }

  const sourceMeta = await sharp(SOURCE).metadata()
  console.log(`Source image: ${sourceMeta.width}x${sourceMeta.height}`)

  // 1. Generate legacy launcher icons (ic_launcher.png)
  for (const [dir, size] of Object.entries(ICON_SIZES)) {
    const outDir = path.join(RES_DIR, dir)
    if (!fs.existsSync(outDir)) {
      fs.mkdirSync(outDir, { recursive: true })
    }
    const outFile = path.join(outDir, 'ic_launcher.png')
    await sharp(SOURCE)
      .resize(size, size, { fit: 'cover', position: 'center' })
      .png()
      .toFile(outFile)
    console.log(`  Generated: ${path.relative(ROOT, outFile)} (${size}x${size})`)
  }

  // 2. Generate adaptive icon foreground (ic_launcher_foreground.png)
  //    The logo is centered with padding (safe zone = 72dp out of 108dp for foreground)
  for (const [dir, size] of Object.entries(FOREGROUND_SIZES)) {
    const outDir = path.join(RES_DIR, dir)
    if (!fs.existsSync(outDir)) {
      fs.mkdirSync(outDir, { recursive: true })
    }
    const outFile = path.join(outDir, 'ic_launcher_foreground.png')

    // Foreground image: logo centered on transparent background
    // The actual icon content should fit within 72dp (2/3 of 108dp)
    const iconSize = Math.round(size * 72 / 108)
    const padding = Math.round((size - iconSize) / 2)

    // Resize the source to fit the safe zone
    const resized = await sharp(SOURCE)
      .resize(iconSize, iconSize, { fit: 'contain', background: BG_COLOR })
      .png()
      .toBuffer()

    // Place on transparent canvas with padding
    await sharp({
      create: {
        width: size,
        height: size,
        channels: 4,
        background: { r: 0, g: 0, b: 0, alpha: 0 }
      }
    })
      .composite([{ input: resized, left: padding, top: padding }])
      .png()
      .toFile(outFile)
    console.log(`  Generated: ${path.relative(ROOT, outFile)} (${size}x${size})`)
  }

  // 3. Generate round icons (ic_launcher_round.png) - same as legacy for simplicity
  for (const [dir, size] of Object.entries(ICON_SIZES)) {
    const outDir = path.join(RES_DIR, dir)
    const outFile = path.join(outDir, 'ic_launcher_round.png')

    // Create a circular mask
    const circleSvg = `<svg width="${size}" height="${size}">
      <circle cx="${size / 2}" cy="${size / 2}" r="${size / 2}" fill="white"/>
    </svg>`

    const resized = await sharp(SOURCE)
      .resize(size, size, { fit: 'cover', position: 'center' })
      .png()
      .toBuffer()

    await sharp(resized)
      .composite([{
        input: Buffer.from(circleSvg),
        blend: 'dest-in'
      }])
      .png()
      .toFile(outFile)
    console.log(`  Generated: ${path.relative(ROOT, outFile)} (${size}x${size})`)
  }

  // 4. Update ic_launcher_background.xml color to white
  const valuesDir = path.join(RES_DIR, 'values')
  const bgFile = path.join(valuesDir, 'ic_launcher_background.xml')
  const bgContent = `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FFFFFF</color>
</resources>
`
  fs.writeFileSync(bgFile, bgContent)
  console.log(`  Updated: ${path.relative(ROOT, bgFile)}`)

  console.log('\nAll Android icons generated successfully!')
}

generateIcons().catch(err => {
  console.error('Error generating icons:', err)
  process.exit(1)
})
