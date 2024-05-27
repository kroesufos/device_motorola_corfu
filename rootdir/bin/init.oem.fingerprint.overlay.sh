#!/vendor/bin/sh
#
# Identify fingerprint sensor model
#
# Copyright (c) 2019 Lenovo
# All rights reserved.
#
# Changed Log:
# ---------------------------------
# April 15, 2019  chengql2@lenovo.com  Initial version
# April 28, 2019  chengql2  Add fps_id creating step
# December 2, 2019  chengql2  Store fps_id into persist fs, and identify sensor
#                             again when secure unit boots as factory mode.

script_name=${0##*/}
script_name=${script_name%.*}
function log {
    echo "$script_name: $*" > /dev/kmsg
}

CHARGER_BOOT=charger
prop_boot_mode=ro.boot.mode
boot_mode=$(getprop $prop_boot_mode)
log "boot mode is: $boot_mode"
if [ $boot_mode == $CHARGER_BOOT ]; then
    log "bootmode is charger mode, don't start FPS"
    return 0
fi

persist_fps_id=/mnt/vendor/persist/fps/vendor_id

FPS_VENDOR_EGIS=egis
FPS_VENDOR_FPC=fpc
FPS_VENDOR_NONE=none
PROP_FPS_IDENT=vendor.hw.fps.ident
MAX_TIMES=20
function ident_fps {
    log "- install FPC driver"
    insmod /vendor/lib/modules/fpc_mtk_tee.ko
#    sleep 1
    sleep 5
    #restorecon -R  /sys/devices/platform/1100a000.spi0/spi_master/spi0/spi0.0/
    log "- identify FPC sensor"
    setprop $PROP_FPS_IDENT ""
    start fpc_ident
    for i in $(seq 1 $MAX_TIMES)
    do
        sleep 0.1
        ident_status=$(getprop $PROP_FPS_IDENT)
        log "-result : $ident_status"
        if [ $ident_status == $FPS_VENDOR_FPC ]; then
            log "ok"
            echo $FPS_VENDOR_FPC > $persist_fps_id
			start vendor.fps-hal-sh
            return 0
        elif [ $ident_status == $FPS_VENDOR_NONE ]; then
            log "fail"
            log "- unload FPC driver"
            rmmod fpc_mtk_tee.ko
            break
        fi
    done

    log "- install Egis driver"
    insmod /vendor/lib/modules/ets_fps.ko
    echo $FPS_VENDOR_EGIS > $persist_fps_id
	sleep 0.5
	start vendor.fps-hal-sh
    return 0
}

if [ ! -f $persist_fps_id ]; then
    ident_fps
    return $?
fi

fps_vendor=$(cat $persist_fps_id)
if [ -z $fps_vendor ]; then
    fps_vendor=$FPS_VENDOR_NONE
fi
log "FPS vendor: $fps_vendor"

if [ $fps_vendor == $FPS_VENDOR_EGIS ]; then
    log "- install Egis driver"
    insmod /vendor/lib/modules/ets_fps.ko
#	sleep 1
	sleep 5
	start vendor.fps-hal-sh
    return $?
fi

if [ $fps_vendor == $FPS_VENDOR_FPC ]; then
    log "- install FPC driver"
    insmod /vendor/lib/modules/fpc_mtk_tee.ko
#	sleep 1
	sleep 5
	start vendor.fps-hal-sh
    return $?
fi

ident_fps
return $?
