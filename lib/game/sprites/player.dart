// Copyright 2022 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_rive/flame_rive.dart';
import 'package:flutter/services.dart';

import '../doodle_dash.dart';
import 'sprites.dart';

enum PlayerState {
  left,
  right,
  center,
  rocket,
  nooglerCenter,
  nooglerLeft,
  nooglerRight
}

abstract class Player extends PositionComponent {
  bool get isMovingDown;

  @override
  NotifyingVector2 get position;

  void resetPosition() {}
  void reset() {}
  void setJumpSpeed(double newJumpSpeed) {}
  void moveLeft() {}
  void moveRight() {}
  void resetDirection() {}
}

class PlayerSprite extends SpriteGroupComponent<PlayerState>
    with HasGameRef<DoodleDash>, KeyboardHandler, CollisionCallbacks
    implements Player {
  PlayerSprite({
    super.position,
    required this.character,
    this.jumpSpeed = 600,
  }) : super(
          size: Vector2(79, 109),
          anchor: Anchor.center,
          priority: 1,
        );

  int _hAxisInput = 0;
  final int movingLeftInput = -1;
  final int movingRightInput = 1;
  Vector2 _velocity = Vector2.zero();

  @override
  bool get isMovingDown => _velocity.y > 0;

  Character character;
  double jumpSpeed;
  final double _gravity = 9;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    await add(CircleHitbox());

    await _loadCharacterSprites();
    current = PlayerState.center;
  }

  @override
  void update(double dt) {
    if (gameRef.gameManager.isIntro || gameRef.gameManager.isGameOver) return;

    _velocity.x = _hAxisInput * jumpSpeed;

    final double dashHorizontalCenter = size.x / 2;

    if (position.x < dashHorizontalCenter) {
      position.x = gameRef.size.x - (dashHorizontalCenter);
    }
    if (position.x > gameRef.size.x - (dashHorizontalCenter)) {
      position.x = dashHorizontalCenter;
    }

    _velocity.y += _gravity;

    position += _velocity * dt;

    super.update(dt);
  }

  @override
  bool onKeyEvent(RawKeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _hAxisInput = 0;

    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
      moveLeft();
    }

    if (keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
      moveRight();
    }

    // During development, its useful to "cheat"
    if (keysPressed.contains(LogicalKeyboardKey.arrowUp)) {
      // jump();
    }

    return true;
  }

  @override
  void moveLeft() {
    _hAxisInput = 0;

    if (isWearingHat) {
      current = PlayerState.nooglerLeft;
    } else if (!hasPowerup) {
      current = PlayerState.left;
    }

    _hAxisInput += movingLeftInput;
  }

  @override
  void moveRight() {
    _hAxisInput = 0; // by default not going left or right

    if (isWearingHat) {
      current = PlayerState.nooglerRight;
    } else if (!hasPowerup) {
      current = PlayerState.right;
    }
    _hAxisInput += movingRightInput;
  }

  @override
  void resetDirection() {
    _hAxisInput = 0;
  }

  bool get hasPowerup =>
      current == PlayerState.rocket ||
      current == PlayerState.nooglerLeft ||
      current == PlayerState.nooglerRight ||
      current == PlayerState.nooglerCenter;

  bool get isInvincible => current == PlayerState.rocket;

  bool get isWearingHat =>
      current == PlayerState.nooglerLeft ||
      current == PlayerState.nooglerRight ||
      current == PlayerState.nooglerCenter;

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is EnemyPlatform && !isInvincible) {
      gameRef.onLose();
      return;
    }

    bool isCollidingVertically =
        (intersectionPoints.first.y - intersectionPoints.last.y).abs() < 5;

    if (isMovingDown && isCollidingVertically) {
      current = PlayerState.center;
      if (other is NormalPlatform) {
        jump();
        return;
      } else if (other is SpringBoard) {
        jump(specialJumpSpeed: jumpSpeed * 2);
        return;
      } else if (other is BrokenPlatform &&
          other.current == BrokenPlatformState.cracked) {
        jump();
        other.breakPlatform();
        return;
      }
    }

    if (!hasPowerup && other is Rocket) {
      current = PlayerState.rocket;
      other.removeFromParent();
      jump(specialJumpSpeed: jumpSpeed * other.jumpSpeedMultiplier);
      return;
    } else if (!hasPowerup && other is NooglerHat) {
      if (current == PlayerState.center) current = PlayerState.nooglerCenter;
      if (current == PlayerState.left) current = PlayerState.nooglerLeft;
      if (current == PlayerState.right) current = PlayerState.nooglerRight;
      other.removeFromParent();
      _removePowerupAfterTime(other.activeLengthInMS);
      jump(specialJumpSpeed: jumpSpeed * other.jumpSpeedMultiplier);
      return;
    }
  }

  void jump({double? specialJumpSpeed}) {
    _velocity.y = specialJumpSpeed != null ? -specialJumpSpeed : -jumpSpeed;
  }

  void _removePowerupAfterTime(int ms) {
    Future.delayed(Duration(milliseconds: ms), () {
      current = PlayerState.center;
    });
  }

  @override
  void setJumpSpeed(double newJumpSpeed) {
    jumpSpeed = newJumpSpeed;
  }

  @override
  void reset() {
    _velocity = Vector2.zero();
    current = PlayerState.center;
  }

  @override
  void resetPosition() {
    position = Vector2(
      (gameRef.size.x - size.x) / 2,
      (gameRef.size.y - size.y) / 2,
    );
  }

  Future<void> _loadCharacterSprites() async {
    // Load & configure sprite assets
    final left = await gameRef.loadSprite('game/${character.name}_left.png');
    final right = await gameRef.loadSprite('game/${character.name}_right.png');
    final center =
        await gameRef.loadSprite('game/${character.name}_center.png');
    final rocket = await gameRef.loadSprite('game/rocket_4.png');
    final nooglerCenter =
        await gameRef.loadSprite('game/${character.name}_hat_center.png');
    final nooglerLeft =
        await gameRef.loadSprite('game/${character.name}_hat_left.png');
    final nooglerRight =
        await gameRef.loadSprite('game/${character.name}_hat_right.png');

    sprites = <PlayerState, Sprite>{
      PlayerState.left: left,
      PlayerState.right: right,
      PlayerState.center: center,
      PlayerState.rocket: rocket,
      PlayerState.nooglerCenter: nooglerCenter,
      PlayerState.nooglerLeft: nooglerLeft,
      PlayerState.nooglerRight: nooglerRight,
    };
  }
}

/// A [Rive](https://rive.app) animated player!
class PlayerRive extends RiveComponent
    with HasGameRef<DoodleDash>, KeyboardHandler, CollisionCallbacks
    implements Player {
  PlayerRive({
    super.position,
    required super.artboard,
    required this.character,
    this.jumpSpeed = 600,
  }) : super(
          size: Vector2(100, 146),
          // size: Vector2(300, 438),
          anchor: Anchor.bottomCenter,
          priority: 1,
        );

  PlayerState current = PlayerState.center;
  late StateMachineController stateMachineController;
  SMITrigger? _lookCenterTrigger;
  SMITrigger? _lookLeftTrigger;
  SMITrigger? _lookRightTrigger;
  SMITrigger? _bounceTrigger;
  SMIInput<bool>? _idleTrigger;
  SMIInput<bool>? _flyingTrigger;
  SMIInput<bool>? _bladeSpinFastTrigger;
  SMIInput<bool>? _jetpackTrigger;
  SMIInput<bool>? _bladSpinOffTrigger;

  int _hAxisInput = 0;
  final int movingLeftInput = -1;
  final int movingRightInput = 1;
  Vector2 _velocity = Vector2.zero();
  @override
  bool get isMovingDown => _velocity.y > 0;
  Character character;
  double jumpSpeed;
  final double _gravity = 9;

  /// Do something when the Rive state machine changes state
  void _onStateChange(String stateMachineName, String stateName) {}

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    await add(CircleHitbox());

    _riveSetup();

    current = PlayerState.center;
    _triggerLookCenterAnimation();
  }

  @override
  void update(double dt) {
    if (gameRef.gameManager.isIntro || gameRef.gameManager.isGameOver) return;

    _velocity.x = _hAxisInput * jumpSpeed;

    final double dashHorizontalCenter = size.x / 2;

    if (position.x < dashHorizontalCenter) {
      position.x = gameRef.size.x - (dashHorizontalCenter);
    }
    if (position.x > gameRef.size.x - (dashHorizontalCenter)) {
      position.x = dashHorizontalCenter;
    }

    _velocity.y += _gravity;

    if (_velocity.y > 0) {
      _playFallAnimation();
    }

    position += _velocity * dt;

    super.update(dt);
  }

  @override
  bool onKeyEvent(RawKeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _hAxisInput = 0;

    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
      moveLeft();
    }

    if (keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
      moveRight();
    }

    // During development, its useful to "cheat"
    if (keysPressed.contains(LogicalKeyboardKey.arrowUp)) {
      // jump();
    }

    return true;
  }

  void _riveSetup() {
    const stateMachineName = 'StateMachine'; // The name of your state machine

    var controller = StateMachineController.fromArtboard(
      artboard,
      stateMachineName,
      onStateChange: _onStateChange,
    );

    if (controller != null) {
      stateMachineController = controller;
      artboard.addController(controller);

      // Use the correct names given in the editor for the respective inputs
      _lookCenterTrigger = controller.findSMI('lookCenter');
      _lookLeftTrigger = controller.findSMI('lookLeft');
      _lookRightTrigger = controller.findSMI('lookRight');
      _bounceTrigger = controller.findSMI('bounce');
      _idleTrigger = controller.findInput('idle');
      _flyingTrigger = controller.findInput('flying');
      _bladeSpinFastTrigger = controller.findInput('bladeSpinFast');
      _jetpackTrigger = controller.findInput('Jetpack');
      _bladSpinOffTrigger = controller.findInput('bladeSpinOff');

      if (_lookCenterTrigger == null ||
          _lookLeftTrigger == null ||
          _lookRightTrigger == null ||
          _bounceTrigger == null ||
          _idleTrigger == null ||
          _flyingTrigger == null ||
          _bladeSpinFastTrigger == null ||
          _jetpackTrigger == null ||
          _bladSpinOffTrigger == null) {
        throw Exception('Some Rive inputs were not found');
      }
    } else {
      throw Exception(
          'Could not find state machine with name: $stateMachineName');
    }
  }

  /// Rive Animation: Look center
  void _triggerLookCenterAnimation() {
    _lookCenterTrigger?.fire();
  }

  /// Rive Animation: Look left
  void _triggerLookLeftAnimation() {
    _lookLeftTrigger?.fire();
  }

  /// Rive Animation: Look Right
  void _triggerLookRightAnimation() {
    _lookRightTrigger?.fire();
  }

  /// Rive Animation: Jump
  void _playJumpAnimation() {
    _idleTrigger?.value = false;
    _bounceTrigger?.fire();
  }

  /// Rive Animation: Fly
  void _playTrampolineAnimation() {
    _playFlyAnimation();
  }

  /// Rive Animation: Hat power up
  void _playHatPowerUpAnimation() {
    _playFlyAnimation();
    _bladeSpinFastTrigger?.value = true;
  }

  /// Rive Animation: Rocket power up
  void _playRocketPowerUpAnimation() {
    _playFlyAnimation();
    _jetpackTrigger?.value = true;
  }

  /// Rive Animation: Fall
  void _playFallAnimation() {
    _disableBladeSpinAnimation(true);
    if (_idleTrigger?.value == false) {
      _idleTrigger?.value = true;
    }
    if (_flyingTrigger?.value == true) {
      _flyingTrigger?.value = false;
    }
    if (_bladeSpinFastTrigger?.value == true) {
      _bladeSpinFastTrigger?.value = false;
    }
    if (_jetpackTrigger?.value == true) {
      _jetpackTrigger?.value = false;
    }
    _triggerLookCenterAnimation();
  }

  /// Rive Animation: Disable/Enable blade spinning
  void _disableBladeSpinAnimation(bool state) {
    if (_bladSpinOffTrigger?.value == state) return;
    _bladSpinOffTrigger?.value = state;
  }

  /// Rive Animation: Play flying animation
  void _playFlyAnimation() {
    _disableBladeSpinAnimation(false);
    _flyingTrigger!.value = true;
  }

  /// Rive Animation: Remove all powerup animations
  void _removeAllPowerUpAnimations() {
    _flyingTrigger?.value = false;
    _bladeSpinFastTrigger?.value = false;
    _jetpackTrigger?.value = false;
  }

  @override
  void moveLeft() {
    _hAxisInput = 0;
    _triggerLookLeftAnimation();

    if (isWearingHat) {
      current = PlayerState.nooglerLeft;
    } else if (!hasPowerup) {
      current = PlayerState.left;
    }

    _hAxisInput += movingLeftInput;
  }

  @override
  void moveRight() {
    _hAxisInput = 0; // by default not going left or right
    _triggerLookRightAnimation();

    if (isWearingHat) {
      current = PlayerState.nooglerRight;
    } else if (!hasPowerup) {
      current = PlayerState.right;
    }
    _hAxisInput += movingRightInput;
  }

  @override
  void resetDirection() {
    _triggerLookCenterAnimation();
    _hAxisInput = 0;
  }

  bool get hasPowerup =>
      current == PlayerState.rocket ||
      current == PlayerState.nooglerLeft ||
      current == PlayerState.nooglerRight ||
      current == PlayerState.nooglerCenter;

  bool get isInvincible => current == PlayerState.rocket;

  bool get isWearingHat =>
      current == PlayerState.nooglerLeft ||
      current == PlayerState.nooglerRight ||
      current == PlayerState.nooglerCenter;

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is EnemyPlatform && !isInvincible) {
      gameRef.onLose();
      return;
    }

    bool isCollidingVertically =
        (intersectionPoints.first.y - intersectionPoints.last.y).abs() < 5;

    if (isMovingDown && isCollidingVertically) {
      current = PlayerState.center;
      _triggerLookCenterAnimation();

      if (other is NormalPlatform) {
        jump();
        return;
      } else if (other is SpringBoard) {
        jump(specialJumpSpeed: jumpSpeed * 2);
        _playTrampolineAnimation();
        return;
      } else if (other is BrokenPlatform &&
          other.current == BrokenPlatformState.cracked) {
        jump();
        other.breakPlatform();
        return;
      }
    }

    if (!hasPowerup && other is Rocket) {
      current = PlayerState.rocket;
      other.removeFromParent();
      jump(specialJumpSpeed: jumpSpeed * other.jumpSpeedMultiplier);
      _playRocketPowerUpAnimation();
      return;
    } else if (!hasPowerup && other is NooglerHat) {
      if (current == PlayerState.center) current = PlayerState.nooglerCenter;
      if (current == PlayerState.left) current = PlayerState.nooglerLeft;
      if (current == PlayerState.right) current = PlayerState.nooglerRight;
      other.removeFromParent();
      _removePowerupAfterTime(other.activeLengthInMS);
      jump(specialJumpSpeed: jumpSpeed * other.jumpSpeedMultiplier);
      _playHatPowerUpAnimation();
      return;
    }
  }

  void jump({double? specialJumpSpeed}) {
    _velocity.y = specialJumpSpeed != null ? -specialJumpSpeed : -jumpSpeed;
    _playJumpAnimation();
  }

  void _removePowerupAfterTime(int ms) {
    Future.delayed(Duration(milliseconds: ms), () {
      current = PlayerState.center;
      _triggerLookCenterAnimation();
      _removeAllPowerUpAnimations();
    });
  }

  @override
  void setJumpSpeed(double newJumpSpeed) {
    jumpSpeed = newJumpSpeed;
  }

  @override
  void reset() {
    _velocity = Vector2.zero();
    current = PlayerState.center;
    _triggerLookCenterAnimation();
  }

  @override
  void resetPosition() {
    position = Vector2(
      (gameRef.size.x - size.x) / 2,
      (gameRef.size.y - size.y) / 2,
    );
  }
}
