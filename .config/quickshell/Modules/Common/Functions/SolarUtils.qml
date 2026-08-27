pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property real obliquity: 23.4397
    readonly property real rad: Math.PI / 180

    function toJulian(date: date): real {
        return date.getTime() / 86400000 + 2440587.5
    }

    function fromJulian(julian: real): date {
        return new Date((julian - 2440587.5) * 86400000)
    }

    // the sun's altitude above the horizon, in degrees
    function elevation(date, latitude: real, longitude: real): real {
        const days = toJulian(date) - 2451545.0
        const anomaly = rad * (357.5291 + 0.98560028 * days)
        const center = rad * (1.9148 * Math.sin(anomaly)
            + 0.02 * Math.sin(2 * anomaly)
            + 0.0003 * Math.sin(3 * anomaly))
        const ecliptic = anomaly + center + rad * 102.9372 + Math.PI
        const declination = Math.asin(Math.sin(ecliptic) * Math.sin(rad * obliquity))
        const rightAscension = Math.atan2(Math.sin(ecliptic) * Math.cos(rad * obliquity), Math.cos(ecliptic))
        const siderealTime = rad * (280.16 + 360.9856235 * days) + rad * longitude
        const hourAngle = siderealTime - rightAscension
        return Math.asin(Math.sin(rad * latitude) * Math.sin(declination)
            + Math.cos(rad * latitude) * Math.cos(declination) * Math.cos(hourAngle)) / rad
    }

    // clock times the sun crosses `elevation` degrees, null on polar day or night
    function crossings(date, latitude: real, longitude: real, elevation: real) {
        const days = Math.round(toJulian(date) - 2451545.0 + 0.0008)
        const solarNoon = days - longitude / 360
        const anomaly = (357.5291 + 0.98560028 * solarNoon) % 360
        const center = 1.9148 * Math.sin(anomaly * rad)
            + 0.02 * Math.sin(2 * anomaly * rad)
            + 0.0003 * Math.sin(3 * anomaly * rad)
        const ecliptic = (anomaly + center + 180 + 102.9372) % 360
        const transit = 2451545.0 + solarNoon
            + 0.0053 * Math.sin(anomaly * rad)
            - 0.0069 * Math.sin(2 * ecliptic * rad)
        const declination = Math.asin(Math.sin(ecliptic * rad) * Math.sin(obliquity * rad))
        const cosHourAngle = (Math.sin(elevation * rad) - Math.sin(latitude * rad) * Math.sin(declination))
            / (Math.cos(latitude * rad) * Math.cos(declination))
        if (cosHourAngle < -1 || cosHourAngle > 1)
            return null

        const hourAngle = Math.acos(cosHourAngle) / rad
        return {
            "rising": fromJulian(transit - hourAngle / 360),
            "setting": fromJulian(transit + hourAngle / 360)
        }
    }
}
