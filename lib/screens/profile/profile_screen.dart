import 'package:flutter/material.dart';

/// 我的模块
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 用户卡
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal[400]!, Colors.teal[700]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('我的账本', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('数据全部保存在本设备', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 功能
          const Text('功能', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _MenuTile(icon: Icons.menu_book, title: '财务小知识', subtitle: '边用边学', onTap: () {}),
          _MenuTile(icon: Icons.notifications_outlined, title: '提醒设置', subtitle: '还款日 / 到期提醒', onTap: () {}),
          _MenuTile(icon: Icons.lock_outline, title: '应用锁', subtitle: '打开软件要密码', onTap: () {}),
          _MenuTile(icon: Icons.file_upload_outlined, title: '导出数据', subtitle: 'CSV / Excel', onTap: () {}),
          _MenuTile(icon: Icons.file_download_outlined, title: '导入数据', subtitle: '从其他软件迁移', onTap: () {}),
          _MenuTile(icon: Icons.palette_outlined, title: '外观', subtitle: '深色 / 浅色', onTap: () {}),
          const SizedBox(height: 24),
          // 管理
          const Text('管理', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _MenuTile(icon: Icons.category_outlined, title: '分类管理', subtitle: '自定义收支分类', onTap: () {}),
          _MenuTile(icon: Icons.account_balance_outlined, title: '账户管理', subtitle: '添加 / 编辑 / 归档', onTap: () {}),
          _MenuTile(icon: Icons.delete_outline, title: '回收站', subtitle: '误删可恢复', onTap: () {}),
          const SizedBox(height: 24),
          // 关于
          const Text('关于', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _MenuTile(icon: Icons.info_outline, title: '版本 1.0.0', subtitle: '关于本软件', onTap: () {}),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _MenuTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Icon(icon, color: Colors.teal),
        title: Text(title),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
