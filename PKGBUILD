pkgname=pacaur
pkgver=0.9.3
pkgrel=1
pkgdesc="A simple cower wrapper to fetch PKGBUILDS from aur & abs"
arch=('any')
url="https://github.com/Spyhawk/pacaur"
license=('GPL')
depends=('cower' 'sudo')
optdepends=('pacman-color: matches output if color is used')
backup=('etc/pacaur.conf')
source=($pkgname $pkgname.conf)
md5sums=('e7f451fcb2f554127c3b1a44fc65e9b5'
         'f4979a0c73f9dc370e39a1f6af92e7a8')
build() {
  mkdir -p "$pkgdir/etc/"
  install -D -m644 ./$pkgname.conf $pkgdir/etc/$pkgname.conf || return 1
  install -D -m755 ./$pkgname $pkgdir/usr/bin/$pkgname || return 1
}
