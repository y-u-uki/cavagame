import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/parallax.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/components.dart';

void main() {
  runApp(GameWidget(game: CavaGame()));
}

class CavaGame extends FlameGame with KeyboardEvents {
  // ===== プレイヤー =====
  double playerX = 100;
  double playerY = 300;
  final double playerSize = 40;

  double vx = 0;
  double vy = 0;

  final double moveSpeed = 300;
  final double jumpPower = 600;
  final double gravity = 1500;
  late double groundY;

  bool leftPressed = false;
  bool rightPressed = false;

  int jumpCount = 0;
  final int maxJumpCount = 2;

  bool isGameOver = false;

  // ===== スコア・速度 =====
  double score = 0;
  double gameSpeed = 260;
  final double speedIncreaseRate = 12;

  // ===== パララックス背景 =====
  late ParallaxComponent bg;

  // ===== プレイヤー画像 =====
  late ui.Image playerIdleImage;
  late ui.Image playerJumpImage;

  // ===== 障害物 =====
  final int obstacleCount = 3;
  final double obstacleWidth = 40;
  final double obstacleHeight = 60;

  final List<double> obstacleX = [];
  final List<double> obstacleY = [];
  final Random random = Random();

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    groundY = size.y - playerSize;

    // ===== プレイヤー画像読み込み =====
    playerIdleImage = await images.load('player_idle.png');
    playerJumpImage = await images.load('player_jump.png');

    // ===== パララックス背景 =====
    bg = await loadParallaxComponent(
      [
        ParallaxImageData('parallax/paris_far.png'),
        ParallaxImageData('parallax/paris_mid.png'),
        ParallaxImageData('parallax/paris_front.png'),
      ],
      baseVelocity: Vector2(40, 0),
      velocityMultiplierDelta: Vector2(1.6, 0), // ★ 奥行き
      repeat: ImageRepeat.repeatX,
    );

    bg
      ..size = size
      ..position = Vector2.zero();

    add(bg);

    // 起動時も resetGame から開始
    resetGame();
  }

  void resetGame() {
    playerX = 100;
    playerY = groundY;
    vx = 0;
    vy = 0;

    jumpCount = 0;
    isGameOver = false;

    score = 0;
    gameSpeed = 260;

    obstacleX.clear();
    obstacleY.clear();
    for (int i = 0; i < obstacleCount; i++) {
      obstacleX.add(size.x + i * 260);
      obstacleY.add(groundY);
    }

    // BGM
    FlameAudio.bgm.stop();
    FlameAudio.bgm.play('bgm.mp3', volume: 0.5);

    resumeEngine();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isGameOver) return;

    score += dt;
    gameSpeed += speedIncreaseRate * dt;

    // 背景追従
    bg.parallax?.baseVelocity.x = gameSpeed * 0.25;

    // 横移動
    if (leftPressed)
      vx = -moveSpeed;
    else if (rightPressed)
      vx = moveSpeed;
    else
      vx = 0;

    playerX += vx * dt;
    playerX = playerX.clamp(0, size.x - playerSize);

    // 重力
    vy += gravity * dt;
    playerY += vy * dt;

    // 着地
    if (playerY >= groundY) {
      playerY = groundY;
      vy = 0;
      jumpCount = 0;
    }

    final playerRect = Rect.fromLTWH(playerX, playerY, playerSize, playerSize);

    // 障害物
    for (int i = 0; i < obstacleX.length; i++) {
      obstacleX[i] -= gameSpeed * dt;

      if (obstacleX[i] < -obstacleWidth) {
        obstacleX[i] = size.x + random.nextInt(300) + 200;
      }

      final obstacleRect = Rect.fromLTWH(
        obstacleX[i],
        obstacleY[i],
        obstacleWidth,
        obstacleHeight,
      );

      if (playerRect.overlaps(obstacleRect)) {
        isGameOver = true;
        FlameAudio.play('hit.wav');
        FlameAudio.bgm.stop();
        pauseEngine();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    // 背景色（黒帯防止）
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0xFF87A8FF),
    );

    super.render(canvas);

    // 地面ライン
    canvas.drawLine(
      Offset(0, groundY + playerSize),
      Offset(size.x, groundY + playerSize),
      Paint()
        ..color = Colors.green
        ..strokeWidth = 3,
    );

    // ===== プレイヤー描画（画像切替）=====
    final ui.Image currentImage = (vy != 0 || jumpCount > 0)
        ? playerJumpImage
        : playerIdleImage;

    canvas.drawImageRect(
      currentImage,
      Rect.fromLTWH(
        0,
        0,
        currentImage.width.toDouble(),
        currentImage.height.toDouble(),
      ),
      Rect.fromLTWH(playerX, playerY, playerSize, playerSize),
      Paint(),
    );

    // 障害物
    for (int i = 0; i < obstacleX.length; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          obstacleX[i],
          obstacleY[i],
          obstacleWidth,
          obstacleHeight,
        ),
        Paint()..color = Colors.red,
      );
    }

    // スコア
    final scoreText = TextPainter(
      text: TextSpan(
        text: 'Score: ${score.toInt()}',
        style: const TextStyle(color: Colors.white, fontSize: 24),
      ),
      textDirection: TextDirection.ltr,
    );
    scoreText.layout();
    scoreText.paint(canvas, const Offset(20, 20));

    // GAME OVER
    if (isGameOver) {
      final gameOverText = TextPainter(
        text: const TextSpan(
          text: 'GAME OVER\nPress R to Retry',
          style: TextStyle(
            color: Colors.red,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      gameOverText.layout();
      gameOverText.paint(
        canvas,
        Offset((size.x - gameOverText.width) / 2, size.y / 3),
      );
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    leftPressed = keysPressed.contains(LogicalKeyboardKey.arrowLeft);
    rightPressed = keysPressed.contains(LogicalKeyboardKey.arrowRight);

    // 二段ジャンプ
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.space &&
        !isGameOver &&
        jumpCount < maxJumpCount) {
      vy = -jumpPower;
      jumpCount++;
      FlameAudio.play('jump.wav');
    }

    // リトライ
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyR &&
        isGameOver) {
      resetGame();
    }

    return KeyEventResult.handled;
  }
}
