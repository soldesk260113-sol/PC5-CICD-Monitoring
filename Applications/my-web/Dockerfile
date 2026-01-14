FROM node:18-alpine

# 작업 디렉토리 설정
WORKDIR /app
# 의존성 파일 복사
COPY package*.json ./

# 프로덕션 의존성만 설치
RUN npm install --production

# 소스 코드 복사
COPY src/ ./src/

# 비 root 사용자 생성 및 전환
RUN addgroup -g 1001 -S nodejs && \
  adduser -S nodejs -u 1001 && \
  chown -R nodejs:nodejs /app

USER nodejs

# 포트 노출
EXPOSE 3000

# 환경 변수
ENV NODE_ENV=production \
  PORT=3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# 애플리케이션 실행
CMD ["node", "src/index.js"]
