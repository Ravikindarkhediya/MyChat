import 'package:animated_background/animated_background.dart';
import 'package:flutter/material.dart';

class Common{

  Behaviour buildBehaviour() {
    return RandomParticleBehaviour(
      options: const ParticleOptions(
        baseColor: Colors.white,
        spawnOpacity: 0.0,
        opacityChangeRate: 0.25,
        minOpacity: 0.1,
        maxOpacity: 0.4,
        spawnMinSpeed: 30.0,
        spawnMaxSpeed: 70.0,
        spawnMinRadius: 2.0,
        spawnMaxRadius: 6.0,
        particleCount: 80,
      ),
      paint: Paint()
        ..style = PaintingStyle.fill,
    );
  }


}