"""Build the Rune Below ZIP for a manual PortMaster install."""
from io import BytesIO
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

root = Path(__file__).resolve().parent
game = BytesIO()
with ZipFile(game, "w", ZIP_DEFLATED) as archive:
    for source in sorted(root.glob("*.lua")):
        archive.write(source, source.name)

launcher = ZipInfo("Rune Below.sh")
launcher.create_system = 3
launcher.external_attr = 0o100755 << 16
output = root / "RuneBelow-R36S.zip"
with ZipFile(output, "w", ZIP_DEFLATED) as archive:
    archive.writestr(launcher, (root / launcher.filename).read_bytes().replace(b"\r\n", b"\n"))
    archive.writestr("rune-below/RuneBelow.love", game.getvalue())
    archive.write(root / "README.md", "README.md")

print(output)
