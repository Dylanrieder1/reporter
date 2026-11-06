import os

def configure():
    print("开始自动配置 Android 原生工程参数...")

    # 1. 注入通讯录权限到 AndroidManifest.xml
    manifest_path = "android/app/src/main/AndroidManifest.xml"
    if os.path.exists(manifest_path):
        with open(manifest_path, "r", encoding="utf-8") as f:
            content = f.read()
        perms = "    <uses-permission android:name=\"android.permission.READ_CONTACTS\" />\n    <uses-permission android:name=\"android.permission.WRITE_CONTACTS\" />\n"
        if "READ_CONTACTS" not in content:
            content = content.replace("<application", perms + "    <application")
            with open(manifest_path, "w", encoding="utf-8") as f:
                f.write(content)
        print(" -> AndroidManifest.xml 权限注入完成")

    # 2. 统一主模块 compileSdk 为 36
    app_gradle = "android/app/build.gradle.kts"
    if os.path.exists(app_gradle):
        with open(app_gradle, "r", encoding="utf-8") as f:
            c = f.read()
        c = c.replace("compileSdk = flutter.compileSdkVersion", "compileSdk = 36")
        with open(app_gradle, "w", encoding="utf-8") as f:
            f.write(c)
        print(" -> 主模块 compileSdk 设置为 36 完成")

    # 3. 在 gradle.properties 中添加 suppress 标识
    prop_path = "android/gradle.properties"
    if os.path.exists(prop_path):
        with open(prop_path, "r", encoding="utf-8") as f:
            existing_props = f.read()
        if "suppressUnsupportedCompileSdk" not in existing_props:
            with open(prop_path, "a", encoding="utf-8") as f:
                f.write("\nandroid.suppressUnsupportedCompileSdk=36\n")
            print(" -> gradle.properties 配置完成")
        else:
            print(" -> gradle.properties 已配置，跳过（幂等）")

    # 4. 在根 build.gradle.kts 中为所有子模块统一升级 compileSdk 为 36
    #    注意：Flutter 模板根 gradle 已有 subprojects { project.evaluationDependsOn(":app") }，
    #    导致 :app 在此脚本执行时已被评估，直接注册 afterEvaluate 会抛出
    #    "Cannot run Project.afterEvaluate(Action) when the project is already evaluated"。
    #    因此必须先检查 project.state.executed，已评估则直接执行，未评估才注册 afterEvaluate。
    root_gradle = "android/build.gradle.kts"
    sub_code = """
// ===== [auto] unify compileSdk for all Android subprojects (do not edit manually) =====
subprojects {
    val proj = this
    val applySdk = {
        val ext = proj.extensions.findByName("android")
        if (ext != null) {
            try {
                ext.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType).invoke(ext, 36)
            } catch (e: Throwable) {
                try {
                    ext.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType).invoke(ext, 36)
                } catch (e2: Throwable) {
                }
            }
        }
    }
    if (proj.state.executed) {
        applySdk()
    } else {
        proj.afterEvaluate { applySdk() }
    }
}
// ===== [/auto] =====
"""
    marker = "// ===== [auto] unify compileSdk"
    if os.path.exists(root_gradle):
        with open(root_gradle, "r", encoding="utf-8") as f:
            existing = f.read()
        if marker in existing:
            print(" -> 根 build.gradle.kts 已包含统一配置，跳过（幂等）")
        else:
            with open(root_gradle, "a", encoding="utf-8") as f:
                f.write("\n" + sub_code + "\n")
            print(" -> 根 build.gradle.kts subprojects 统一配置完成")

if __name__ == '__main__':
    configure()
