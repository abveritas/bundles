#!/bin/bash

# bundle.sh, automation script for the creation and maintenance of cinstall bundles
#
# Copyright (c) 2010 by Manuel Tortosa <manutortosa[at]chakra-project[dot]org
#                       Drake Justice <djustice[at]chakra-project[dot]org
# GPL
#



source _buildscripts/functions/messages
source _buildscripts/functions/dependency_handling




clean()
{
    msg "Cleaning work directories"

    for pkg in ${pkgz_to_build} ; do
        pushd ${pkg} &>/dev/null
            rm -rf pkg src dbg hdr &>/dev/null
        popd &>/dev/null
    done


    newline
    msg "Removing installed packages"

    local clean_list

    # dont remove certain pkgz, or it would be too easy to break important binaries..
    for pkg in ${pkgz_to_build} ; do
        [[ "$(echo ${pkg} | cut -c1)" == "#" ]] && continue
        [[ ${pkgz_to_keep} == *${pkg}* ]] && continue
        clean_list="${clean_list} ${pkg}"
    done

    sudo pacman -Rd --noconfirm ${clean_list} &>/dev/null


    newline
    msg "Removing leftover files in _temp..."

    if [ "${arg}" != "-c" ] ; then
        rm _temp/*.pkg.tar.{x,g}z &>/dev/null
    fi

    rm -rf _temp/{usr,etc,opt,tmpbundle,.*,*.cb,*.pkg.tar} &>/dev/null
}

bundle()
{
    pkgdir=$(echo ${pkg_} | sed -e 's,["/],,g')
    pkgbuild=$(cat ${pkgdir}/PKGINFO | grep name | cut -d= -f2)

    source ${pkgdir}/${pkgbuild}/PKGBUILD

    pushd _temp &>/dev/null

        newline
        msg "Creating bundle: $(cat ../${pkgdir}/PKGINFO | grep "name=" | cut -d"=" -f2)-${pkgver}-${pkgrel}-${_arch}"
        newline

        if [ ! -e "../${pkgdir}/$(cat ../${pkgdir}/PKGINFO | grep "desktop=" | cut -d"=" -f2)" ] ; then
            error "can't find $(cat ../${pkgdir}/PKGINFO | grep "desktop=" | cut -d"=" -f2), exiting..."
            exit 1
        fi

        if [ ! -e "../${pkgdir}/$(cat ../${pkgdir}/PKGINFO | grep "icon=" | cut -d"=" -f2)" ] ; then
            error "can't find $(cat ../${pkgdir}/PKGINFO | grep "icon=" | cut -d"=" -f2), exiting..."
            exit 1
        fi

        # copy/move/extract pkg data
        mkdir ../_pkgz &>/dev/null
        cp -f *.pkg.tar.* ../_pkgz &>/dev/null

        for pkg in ${pkgz_to_bundle} ; do
            [[ `echo ${pkg} | cut -c1` == '#' ]] && continue

            if [ -e ${pkg}-[0-9]*-*.tar.xz ] ; then
                status_start "Extracting xz package ${pkg}..."
                    xz -d ${pkg}-[0-9]*-*.pkg.tar.xz && &>/dev/null
                    tar xf ${pkg}-[0-9]*-*.pkg.tar &>/dev/null
                status_done
            elif [ -e ${pkg}-[0-9]*-*.pkg.tar.gz ] ; then
                status_start "Extracting gz package ${pkg}..."
                    tar zxf ${pkg}-[0-9]*-*.pkg.tar.gz &>/dev/null
                status_done
            elif [ -e ${pkg}-[0-9]*-*.pkg.tar ] ; then
                status_start "Extracting tar package ${pkg}..."
                    tar xf ${pkg}-[0-9]*-*.pkg.tar &>/dev/null
                status_done
            elif [ "$(pacman -Ssq | grep ${pkg})" != "" ] ; then
                sudo pacman -S --noconfirm ${pkg} &>/dev/null
                status_start "Extracting xz package ${pkg}..."
                    cp /var/cache/pacman/pkg/${pkg}*.pkg.* . &>/dev/null
                    cp /var/cache/pacman/pkg/${pkg}*.pkg.* ../_pkgz &>/dev/null
                    xz -d ${pkg}-[0-9]*-*.pkg.tar.xz && &>/dev/null
                    tar xf ${pkg}-[0-9]*-*.pkg.tar &>/dev/null
                status_done
            else
                newline
                error "Can't find or obtain the needed package in _temp dir: ${pkg}"
                exit 1
            fi
        done

        # test for chrooted bundle
        chrooted=$(cat ../${pkgdir}/PKGINFO | grep "chroot=" | cut -d "=" -f2)

        # no chroot line, non-chroot bundle
        if [ "${chrooted}" = "" ] || [[ ! "${chrooted}" = *[tTfF]* ]] ; then
            chrooted="false"
        fi

        if [[ "${chrooted}" = [\ fF]* ]] ; then
            # non-chrooted

            # tmpdir
            mkdir tmpbundle &>/dev/null

            # populate it
            cp -rf usr etc opt tmpbundle &>/dev/null
            cp -f ../${pkgdir}/*.{sh,desktop,png,txt,html,LICENSE} tmpbundle &>/dev/null

            # create PKGINFO
            echo "version=${pkgver}" >> tmpbundle/PKGINFO
            echo "release=${pkgrel}" >> tmpbundle/PKGINFO
            echo "description=${pkgdesc}" >> tmpbundle/PKGINFO
            echo "url=${url}" >> tmpbundle/PKGINFO
            echo "packager=${PACKAGER}" >> tmpbundle/PKGINFO

            if [[ "${type}" = [\ lL]* ]] ; then
                echo "type=Launcher" >> tmpbundle/PKGINFO
            elif [[ "${type}" = [\ iI]* ]] ; then
                echo "type=Installer" >> tmpbundle/PKGINFO
            elif [[ "${type}" = [\ sS]* ]] ; then
                echo "type=Setup" >> tmpbundle/PKGINFO
            fi

            echo "$(cat ../${pkgdir}/PKGINFO | grep -v version | grep -v release | grep -v description | grep -v url | grep -v packager)" >> tmpbundle/PKGINFO


            # trace & strip
            newline
            pushd tmpbundle &>/dev/null
                for binary in $(cat ../../${pkgdir}/PKGINFO | grep binary= | cut -d= -f2) ; do
                    msg "ldd-trace.sh: ${binary}"
                    ../../ldd-trace.sh ${binary}
                done

                if [ "$(cat ../../${pkgdir}/PKGINFO | grep binary= | cut -d= -f2)" = "" ] ; then
                    msg "ldd-trace.sh: $(cat ../../${pkgdir}/PKGINFO | grep exec= | cut -d= -f2)"
                    ../../ldd-trace.sh $(cat ../../${pkgdir}/PKGINFO | grep exec= | cut -d= -f2)
                fi

                ../../ldd-trace.sh $(cat ../../${pkgdir}/PKGINFO | grep exec= | cut -d= -f2)

                if [ -e strip.sh ] ; then
                    ./strip.sh
                fi
            popd &>/dev/null

            # compress
            newline
            msg "Compressing bundle..."
            mksquashfs tmpbundle `cat ../${pkgdir}/PKGINFO | grep "name=" | cut -d "=" -f2`-${pkgver}-${pkgrel}-${_arch}.cb

            # copy to repo
            chmod +rw *.cb
            cp -f *.cb ../_repo/local &>/dev/null
        else
            # chrooted bundle

            # make needed dirs
            sudo umount tmpbundle{/app,/data,_root} &>/dev/null
            rm -rf tmpbundle{/app,/data,_root} &>/dev/null
            mkdir -p tmpbundle{/app,/data,_root} &>/dev/null

            # data ext4 image
            dd if=/dev/zero of=tmpbundle/data.ext4 bs=1024 count=2000 &>/dev/null
            mkfs.ext4 -F tmpbundle/data.ext4 &>/dev/null
            sudo mount -o loop -t ext4 data.ext4 tmpbundle/data &>/dev/null
                rm -rf tmpbundle/data/lost+found &>/dev/null
            sudo umount tmpbundle/data &>/dev/null

            # app sqfs image
            rm -f tmpbundle/app.sqfs &>/dev/null
            mv -f usr lib etc opt tmpbundle/app &>/dev/null
            # trace & strip
            newline
            pushd tmpbundle/app &>/dev/null
                for binary in $(cat ../../../${pkgdir}/PKGINFO | grep binary= | cut -d= -f2) ; do
                    msg "ldd-trace.sh: ${binary}"
                    ../../../ldd-trace.sh ${binary}
                done

                if [ "$(cat ../../../${pkgdir}/PKGINFO | grep binary= | cut -d= -f2)" = "" ] ; then
                    msg "ldd-trace.sh: $(cat ../../../${pkgdir}/PKGINFO | grep exec= | cut -d= -f2)"
                    ../../../ldd-trace.sh $(cat ../../../${pkgdir}/PKGINFO | grep exec= | cut -d= -f2)
                fi

                if [ -e ../../../${pkgdir}/strip.sh ] ; then
                    ../../../${pkgdir}/strip.sh
                fi
            popd &>/dev/null
            # compress
            newline
            msg "Compressing bundle..."
            mksquashfs tmpbundle/app tmpbundle/app.sqfs -noappend
            rm -rf tmpbundle/{app,data} &>/dev/null

            # icon, desktop, scripts
            cp -f ../${pkgdir}/*.{sh,desktop,png,svg} tmpbundle &>/dev/null

            # create PKGINFO
            echo "version=${pkgver}" >> tmpbundle/PKGINFO
            echo "release=${pkgrel}" >> tmpbundle/PKGINFO
            echo "description=${pkgdesc}" >> tmpbundle/PKGINFO
            echo "url=${url}" >> tmpbundle/PKGINFO
            echo "packager=${PACKAGER}" >> tmpbundle/PKGINFO
            echo "type=Launcher" >> tmpbundle/PKGINFO
            echo "$(cat ../${pkgdir}/PKGINFO | grep -v version | grep -v release | grep -v description | grep -v url | grep -v packager)" >> tmpbundle/PKGINFO

            # determine final bundle size
            export appSqfsSize=$(du -s tmpbundle/app.sqfs | cut -f1)
            export dataExtSize=$(du -s tmpbundle/data.ext4 | cut -f1)
            export totalSize=$(( appSqfsSize + dataExtSize + 10000 ))

            # remove any preexistent cb
            if [ -f ${pkgdir}-${pkgver}-${pkgrel}-${_arch}.cb ]; then
                rm -f ${pkgdir}-${pkgver}-${pkgrel}-${_arch}.cb &>/dev/null
            fi

            # populate actual bundle image
            dd if=/dev/zero of=${pkgdir}-${pkgver}-${pkgrel}-${_arch}.cb bs=1024 count=$totalSize &>/dev/null
            mkfs.ext4 -F ${pkgdir}-${pkgver}-${pkgrel}-${_arch}.cb &>/dev/null
            sudo mount -o loop -t ext4 ${pkgdir}-${pkgver}-${pkgrel}-${_arch}.cb tmpbundle_root &>/dev/null
                rm -rf tmpbundle_root/lost+found &>/dev/null
                cp -f tmpbundle/* tmpbundle_root &>/dev/null
            sudo umount tmpbundle_root &>/dev/null
            chmod +xrw ${pkgdir}-${pkgver}-${pkgrel}-${_arch}.cb &>/dev/null

            # copy to repo
            cp -f *.cb ../_repo/local &>/dev/null

            # cleanup
            rm -rf tmpbundle_root &>/dev/null
            rm -rf * &>/dev/null
        fi
    popd &>/dev/null
}

build()
{
    for pkg in ${pkgz_to_build} ; do
        [[ "$(echo ${pkg} | cut -c1)" == "#" ]] && continue

        msg "${pkg}"

        # find the .pkg if it exists, copy to _temp and install
        if [ "$(ls _temp | grep ${pkg}-[0-9])" != "" ] ; then
            echo "     found in _temp, skipping the build"
            echo "     installing..."
            sudo pacman -Udf --noconfirm _temp/${pkg}-[0-9]*.pkg.* &>/dev/null
        elif [ "$(ls _pkgz | grep ${pkg}-[0-9])" != "" ] ; then
            echo "     found in _pkgz, skipping the build"
            echo "     installing..."
            sudo pacman -Udf --noconfirm _pkgz/${pkg}-[0-9]*.pkg.* &>/dev/null
            cp _pkgz/${pkg}-*.pkg.* _temp &>/dev/null
            cp _pkgz/${pkg}-*.pkg.* _pkgz &>/dev/null
        elif [ -e ${pkg_}/${pkg}/${pkg}-[0-9]*.pkg.* ] ; then
            echo "     found in pkgdir, skipping the build"
            echo "     installing..."
            cp ${pkg_}/${pkg}-*.pkg.* _temp &>/dev/null
            cp ${pkg_}/${pkg}-*.pkg.* _pkgz &>/dev/null
            sudo pacman -Udf --noconfirm ${pkg_}/${pkg}/${pkg}-[0-9]*.pkg.* &>/dev/null
        elif [ -e ${pkg_}/${pkg}/PKGBUILD ] ; then
            pushd ${pkg_}/${pkg} &>/dev/null
                do_makedeps
                do_deps
                ../../makepkg -sfi --noconfirm || local broken_pkg="1"
                cp ${pkg_}/${pkg}/*.pkg.* ../../_temp &>/dev/null
                cp all_/${pkg}/*.pkg.* ../../_temp &>/dev/null
                cp ${pkg_}/${pkg}/*.pkg.* ../../_pkgz &>/dev/null
                cp all_/${pkg}/*.pkg.* ../../_pkgz &>/dev/null
            popd &>/dev/null
        elif [ -e all_/${pkg}/PKGBUILD ] ; then
            pushd all_/${pkg} &>/dev/null
                do_makedeps
                do_deps
                makepkg -sfi --noconfirm || local broken_pkg="1"
                cp ${pkg_}/${pkg}/*.pkg.* ../../_temp &>/dev/null
                cp all_/${pkg}/*.pkg.* ../../_temp &>/dev/null
                cp ${pkg_}/${pkg}/*.pkg.* ../../_pkgz &>/dev/null
                cp all_/${pkg}/*.pkg.* ../../_pkgz &>/dev/null
            popd &>/dev/null
        elif [ "$(pacman -Ssi | grep "${pkg} ")" != "" ] ; then
            echo "     syncing..."
            sudo pacman -Sdf --noconfirm ${pkg} &>/dev/null
            cp /var/cache/pacman/pkg/${pkg}-[0-9]*.pkg.* _pkgz
            cp /var/cache/pacman/pkg/${pkg}-[0-9]*.pkg.* _temp
        else
            error "No PKGBUILD found, exiting... check the PKGINFO pkgz=/build= lists."
            exit 1
        fi

        if [ "${broken_pkg}" = "1" ] ; then
            error " !! error building: ${pkg}"
            sleep 4
            exit 1
        fi
    done

    if [ "${arg}" != "-o" ] ; then
        newline
        bundle
        newline
        clean
    fi
}





title "bundle(r) script 0.0.x"



pkg_=$(echo $1)
arg=$(echo $2)


if [ "${pkg_}" = "" ] ; then
    error "you must specify a bundle to build."
    exit 1
fi

if [ -e /var/lib/pacman/db.lck ] ; then
    error "pacman database is locked! (/var/lib/pacman/db.lck exists)"
    exit 1
fi

# get the list of packages to build from PKGINFO
pkgz_to_build="$(cat ${pkg_}/PKGINFO | grep "build=" | cut -d= -f2)"

# get the list of packages to bundle from PKGINFO
pkgz_to_bundle="$(cat ${pkg_}/PKGINFO | grep "pkgz=" | cut -d= -f2)"

# create the list of packages to remove
pkgz_to_remove=${pkgz_to_build}

# list of safety pkgz, as minimal chroot
pkgz_to_keep="openssl libjpeg libpng cmake openssh git sudo boost nano vi vim rsync pacman file wget grep gettext repo-clean squashfs-tools dbus pcre bzip2 libsm perl freetype2 dbus-core"

# argument handling
if [ "${arg}" = "" ] || [ "${arg}" = "-o" ] ; then
    time build
    msg "All done"
elif [ "${arg}" = "-c" ] ; then
    time clean
    msg "All done"
elif [ "${arg}" = "-b" ] ; then
    time bundle
    msg "All done"
else
    newline
    msg "Available options: -b only bundle | -c only clean | -o only builds"
fi

newline
