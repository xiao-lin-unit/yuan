import fs from 'fs';
import path from 'path';

// 定义SQLite插件的build.gradle文件路径
const sqliteBuildGradlePath = path.resolve(
  process.cwd(),
  'node_modules',
  '@capacitor-community',
  'sqlite',
  'android',
  'build.gradle'
);

// 定义app的build.gradle文件路径
const appBuildGradlePath = path.resolve(
  process.cwd(),
  'android',
  'app',
  'capacitor.build.gradle'
);

// 定义capacitor-cordova-android-plugins的build.gradle文件路径
const cordovaPluginsBuildGradlePath = path.resolve(
  process.cwd(),
  'android',
  'capacitor-cordova-android-plugins',
  'build.gradle'
);

// 定义Keyboard插件的build.gradle文件路径
const keyboardBuildGradlePath = path.resolve(
  process.cwd(),
  'node_modules',
  '@capacitor',
  'keyboard',
  'android',
  'build.gradle'
);

// 检查文件是否存在
if (fs.existsSync(sqliteBuildGradlePath)) {
  console.log('正在修改 @capacitor-community/sqlite 的 build.gradle 文件...');
  
  // 读取文件内容
  let content = fs.readFileSync(sqliteBuildGradlePath, 'utf8');
  
  // 添加namespace配置
  if (!content.includes('namespace "com.getcapacitor.community.sqlite"')) {
    content = content.replace(
      /plugins \{\s*id "com\.android\.library"/g,
      'plugins {\n    id "com.android.library"\n\n    namespace "com.getcapacitor.community.sqlite"'
    );
  }
  
  // 修改Java版本
  content = content.replace(
    /sourceCompatibility\s*=?\s*JavaVersion\.VERSION_\d+/g,
    'sourceCompatibility JavaVersion.VERSION_17'
  );
  content = content.replace(
    /targetCompatibility\s*=?\s*JavaVersion\.VERSION_\d+/g,
    'targetCompatibility JavaVersion.VERSION_17'
  );
  
  // 写入修改后的内容
  fs.writeFileSync(sqliteBuildGradlePath, content);
  console.log('✅ @capacitor-community/sqlite 的 build.gradle 文件修改成功');
} else {
  console.log('⚠️  @capacitor-community/sqlite 的 build.gradle 文件不存在');
}

// 检查app的capacitor.build.gradle文件
if (fs.existsSync(appBuildGradlePath)) {
  console.log('正在修改 app 的 capacitor.build.gradle 文件...');
  
  // 读取文件内容
  let content = fs.readFileSync(appBuildGradlePath, 'utf8');
  
  // 修改Java版本
  content = content.replace(
    /sourceCompatibility\s+JavaVersion\.VERSION_\d+/g,
    'sourceCompatibility JavaVersion.VERSION_17'
  );
  content = content.replace(
    /targetCompatibility\s+JavaVersion\.VERSION_\d+/g,
    'targetCompatibility JavaVersion.VERSION_17'
  );
  
  // 写入修改后的内容
  fs.writeFileSync(appBuildGradlePath, content);
  console.log('✅ app 的 capacitor.build.gradle 文件修改成功');
} else {
  console.log('⚠️  app 的 capacitor.build.gradle 文件不存在');
}

// 检查capacitor-cordova-android-plugins的build.gradle文件
if (fs.existsSync(cordovaPluginsBuildGradlePath)) {
  console.log('正在修改 capacitor-cordova-android-plugins 的 build.gradle 文件...');
  
  // 读取文件内容
  let content = fs.readFileSync(cordovaPluginsBuildGradlePath, 'utf8');
  
  // 修改Java版本
  content = content.replace(
    /sourceCompatibility\s+JavaVersion\.VERSION_\d+/g,
    'sourceCompatibility JavaVersion.VERSION_17'
  );
  content = content.replace(
    /targetCompatibility\s+JavaVersion\.VERSION_\d+/g,
    'targetCompatibility JavaVersion.VERSION_17'
  );
  
  // 写入修改后的内容
  fs.writeFileSync(cordovaPluginsBuildGradlePath, content);
  console.log('✅ capacitor-cordova-android-plugins 的 build.gradle 文件修改成功');
} else {
  console.log('⚠️  capacitor-cordova-android-plugins 的 build.gradle 文件不存在');
}

// 检查Keyboard插件的build.gradle文件
if (fs.existsSync(keyboardBuildGradlePath)) {
  console.log('正在修改 @capacitor/keyboard 的 build.gradle 文件...');
  
  // 读取文件内容
  let content = fs.readFileSync(keyboardBuildGradlePath, 'utf8');
  
  // 修改Java版本
  content = content.replace(
    /sourceCompatibility\s+JavaVersion\.VERSION_\d+/g,
    'sourceCompatibility JavaVersion.VERSION_17'
  );
  content = content.replace(
    /targetCompatibility\s+JavaVersion\.VERSION_\d+/g,
    'targetCompatibility JavaVersion.VERSION_17'
  );
  
  // 写入修改后的内容
  fs.writeFileSync(keyboardBuildGradlePath, content);
  console.log('✅ @capacitor/keyboard 的 build.gradle 文件修改成功');
} else {
  console.log('⚠️  @capacitor/keyboard 的 build.gradle 文件不存在');
}

console.log('✅ postinstall 脚本执行完成');
