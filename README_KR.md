# AI Voice Recorder

[한국어](./README_KR.md) •
[ENGLISH](./README.md)

## Overview

AI Voice Recorder는 최첨단 음성 인식 기술을 활용한 프리미엄 음성 녹음 및 전사 애플리케이션입니다. 28개 언어를 지원하는 오프라인 음성 처리 엔진을 탑재하여 네트워크 연결 없이도 고정밀 음성-텍스트 변환이 가능합니다. SwiftUI 와 WhisperKit 을 사용하여 기능을 구현했습니다. iOS에서 WhisperKit 모델을 사용하는 방법을 배울수 있습니다.

## Technical Features

### Core Capabilities
- **고성능 오디오 처리 엔진**
  - 48kHz/24bit 고품질 오디오 녹음
  - 실시간 오디오 파형 시각화
  - 노이즈 캔슬링 및 에코 제거

- **AI 음성 인식 시스템**
  - 온디바이스 머신러닝 모델 탑재
  - 실시간 음성-텍스트 변환
  - 다중 화자 식별 및 구분

### Supported Languages
- **28개 언어 지원:**
  - 아시아: 한국어, 일본어, 중국어(간체/번체), 베트남어 등
  - 유럽: 영어, 프랑스어, 독일어, 스페인어 등
  - 기타: 아랍어, 힌디어 등

### System Architecture
- **Storage & Sync**
  - iCloud 기반 데이터 동기화
  - 로컬 SQLite 데이터베이스
  - 증분 백업 시스템

- **File Management**
  - 고급 검색 알고리즘
  - 메타데이터 기반 파일 인덱싱
  - 다양한 오디오/텍스트 포맷 지원

## Use Cases

### Professional Environment
- 회의록 자동 작성
- 인터뷰 기록
- 다국어 비즈니스 미팅

### Academic Setting
- 강의 녹음 및 전사
- 연구 인터뷰 기록
- 학습 자료 작성

### Personal Use
- 아이디어 음성 메모
- 다국어 학습 도구
- 개인 일지 작성

## Privacy & Security

### Data Protection
- 전체 오프라인 처리로 데이터 유출 방지
- End-to-End 암호화 적용
- 개인정보 미수집 정책

### Storage Security
- iCloud 보안 프로토콜 준수
- 로컬 데이터 AES-256 암호화
- 자동 백업 및 복구 시스템

## System Requirements
- iOS 14.0 이상

## Installation
- https://apps.apple.com/kr/app/ai-voice-recorder/id6740986609

