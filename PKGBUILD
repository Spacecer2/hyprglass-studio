# Maintainer: Spacecer2 <https://github.com/Spacecer2>
pkgname=hyprglass-studio
pkgver=1.1.0
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
sha256sums=('70580a9ff089a58ecef1d7ab2407b9db7df451d4fb34e1e46ea42cc793d36c15')

package() {
    cd "${srcdir}/${pkgname}-${pkgver}" || cd "${srcdir}/${pkgname}"
    make DESTDIR="${pkgdir}" PREFIX=/usr install
}
