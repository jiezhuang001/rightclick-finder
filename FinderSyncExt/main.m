// Finder 同步扩展的入口：标准 main，再调用 Foundation 导出的 NSExtensionMain。
// 与 Xcode 构建的 app 扩展二进制结构一致（LC_MAIN + 导入 _NSExtensionMain）。
#import <Foundation/Foundation.h>

// NSExtensionMain 由 Foundation 导出，但不在公开头文件里，这里手动声明。
int NSExtensionMain(int argc, const char *argv[]);

int main(int argc, const char *argv[]) {
    return NSExtensionMain(argc, argv);
}
