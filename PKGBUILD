# Maintainer: Spacecer2 <https://github.com/Spacecer2>
pkgname=hyprglass-studio
pkgver=1.0.0
pkgrel=1
pkgdesc="Apple-style Liquid Glass effects for Hyprland with a web-based Studio UI"
arch=('any')
url="https://github.com/Spacecer2/hyprglass-studio"
license=('MIT')
depends=(
    'hyprland>=0.55'
    'python>=3.10'
    'python-websockets'
    'python-aiohttp'
    'python-aiofiles'
    'python-yaml'
    'jq'
)
optdepends=(
    'wallust: wallpaper color sync'
    'grim: screenshot integration'
    'slurp: screenshot region selection'
)
source=("${pkgname}-${pkgver}.tar.gz::${url}/archive/refs/tags/v${pkgver}.tar.gz")
sha256sums=('92a7dad8d52d9486a8a3df70a1ff4e0d1084f904e593cfdfbd20e36083e038d3')

package() {
    cd "${srcdir}/${pkgname}-${pkgver}" || cd "${srcdir}/${pkgname}"
    make DESTDIR="${pkgdir}" PREFIX=/usr install
}
