import QtQuick
import "root:/"

NumberAnimation {
    id: root

    enum Type {
        DefaultSpatial = 0,
        FastSpatial,
        SlowSpatial,
        DefaultEffects,
        FastEffects
    }

    property int type: Anim.DefaultSpatial

    duration: {
        switch (type) {
        case Anim.FastSpatial:
            return Theme.fastSpatialDuration;
        case Anim.SlowSpatial:
            return Theme.slowSpatialDuration;
        case Anim.DefaultEffects:
            return Theme.effectsDuration;
        case Anim.FastEffects:
            return Theme.fastEffectsDuration;
        case Anim.DefaultSpatial:
        default:
            return Theme.spatialDuration;
        }
    }

    easing.type: Easing.BezierSpline
    easing.bezierCurve: {
        switch (type) {
        case Anim.FastSpatial:
            return Theme.curveFastSpatial;
        case Anim.SlowSpatial:
            return Theme.curveSlowSpatial;
        case Anim.DefaultEffects:
            return Theme.curveDefaultEffects;
        case Anim.FastEffects:
            return Theme.curveFastEffects;
        case Anim.DefaultSpatial:
        default:
            return Theme.curveDefaultSpatial;
        }
    }
}
