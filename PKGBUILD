# Maintainer: Ian Laird <irlaird@gmail.com>
pkgname=pkgsieve
pkgver=0.1.5
pkgrel=1
pkgdesc='Sift AUR PKGBUILDs for supply-chain malware before you build them'
arch=('any')
url='https://github.com/en0/pkgsieve'
license=('MIT')
depends=('bash' 'curl')
optdepends=('pacman: for the --installed audit of already-installed packages')

# Build straight from the local git checkout so this package can be built and
# installed in-place from ~/.aur/pkgsieve (full dogfood). No network source.
source=()

package() {
  cd "$startdir"
  install -Dm755 pkgsieve "$pkgdir/usr/bin/pkgsieve"
  install -Dm644 LICENSE  "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
