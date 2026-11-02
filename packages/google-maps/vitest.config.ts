import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environmentOptions: {
      happyDOM: {
        // 測試插入的 <script> 不能真的去連 Google
        settings: { disableJavaScriptFileLoading: true, handleDisabledFileLoadingAsSuccess: true },
      },
    },
  },
})
