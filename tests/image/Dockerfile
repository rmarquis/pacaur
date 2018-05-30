FROM base/devel
# update the image and install pacaur dependencies
RUN pacman -Syu --noconfirm
RUN pacman -S --noconfirm git expac

# prepare the pacaur environment
RUN useradd -m pacaur
RUN echo 'pacaur ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# build cower
USER pacaur
WORKDIR /home/pacaur
RUN git clone https://aur.archlinux.org/cower.git
WORKDIR /home/pacaur/cower
RUN gpg --recv-keys --keyserver hkp://pgp.mit.edu 1EB2638FF56C0C53
RUN makepkg -sri --noconfirm

RUN mkdir -p /home/pacaur/pacaur
WORKDIR /home/pacaur/pacaur
