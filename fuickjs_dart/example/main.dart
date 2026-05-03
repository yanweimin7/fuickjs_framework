import 'package:fuickjs_dart/fuickjs_dart.dart';

// ---------------------------------------------------------------------------
// Profile Page — 个人主页（复杂示例）
// ---------------------------------------------------------------------------

class ProfilePage extends StatefulWidget {
  const ProfilePage();

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _tab = 0; // 0=动态 1=收藏 2=关注
  bool _followed = false;

  static const _tabs = ['动态', '收藏', '关注'];

  static const _posts = [
    {
      'avatar': 'https://i.pravatar.cc/40?img=1',
      'name': 'Alice',
      'time': '2小时前',
      'content': '今天天气真好，出去散步了一圈，心情愉快 ☀️',
      'likes': 42,
      'comments': 8,
    },
    {
      'avatar': 'https://i.pravatar.cc/40?img=2',
      'name': 'Bob',
      'time': '5小时前',
      'content': '刚看完一本好书《人类简史》，强烈推荐给大家！',
      'likes': 128,
      'comments': 23,
    },
    {
      'avatar': 'https://i.pravatar.cc/40?img=3',
      'name': 'Carol',
      'time': '昨天',
      'content': '分享一个好用的 Flutter 框架 FuickJS，支持动态渲染！',
      'likes': 256,
      'comments': 41,
    },
  ];

  static const _collections = [
    {'title': 'Flutter 最佳实践', 'tag': '技术', 'color': '#E8F4FD'},
    {'title': '2024 年值得读的10本书', 'tag': '阅读', 'color': '#FFF3E0'},
    {'title': '极简主义生活指南', 'tag': '生活', 'color': '#F3E5F5'},
    {'title': 'Dart 异步编程深入解析', 'tag': '技术', 'color': '#E8F5E9'},
  ];

  @override
  FWidget build() {
    return Scaffold(
      backgroundColor: '#F5F5F5',
      appBar: AppBar(
        title: Text('个人主页', fontSize: 17, fontWeight: 'w600', color: '#FFFFFF'),
        backgroundColor: '#1A1A2E',
        foregroundColor: '#FFFFFF',
        centerTitle: true,
        elevation: 0,
        actions: [
          Container(
            width: 44,
            height: 44,
            alignment: 'center',
            onTap: () {
              callNativeAsync('Dialog.showModal', {
                'title': '设置',
                'content': '更多设置功能即将上线',
                'confirmText': '好的',
                'showCancel': false,
              });
            },
            child: Icon(codePoint: 0xe8b8, size: 22, color: '#FFFFFF'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            _buildStats(),
            _buildTabs(),
            _buildTabContent(),
          ],
        ),
      ),
    );
  }

  // ── 顶部封面 + 头像 + 关注按钮 ──────────────────────────────────────────
  FWidget _buildHeader() {
    return Stack(
      children: [
        // 封面背景
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: '#1A1A2E',
            borderRadius: const BorderRadius.only(
              bottomLeft: 0,
              bottomRight: 0,
            ),
          ),
          child: Image(
            src: 'https://picsum.photos/400/160?random=1',
            width: 400,
            height: 160,
            fit: 'cover',
          ),
        ),
        // 头像
        Positioned(
          left: 16,
          top: 110,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(40),
              border: const Border(color: '#FFFFFF', width: 3),
            ),
            child: Image(
              src: 'https://i.pravatar.cc/80?img=5',
              width: 80,
              height: 80,
              fit: 'cover',
              borderRadius: 40,
            ),
          ),
        ),
        // 关注按钮
        Positioned(
          right: 16,
          top: 168,
          child: Container(
            width: 88,
            height: 36,
            alignment: 'center',
            decoration: BoxDecoration(
              color: _followed ? '#F0F0F0' : '#007AFF',
              borderRadius: const BorderRadius.all(18),
            ),
            onTap: () => setState(() => _followed = !_followed),
            child: Text(
              _followed ? '已关注' : '+ 关注',
              fontSize: 14,
              color: _followed ? '#666666' : '#FFFFFF',
              fontWeight: 'w500',
            ),
          ),
        ),
      ],
    );
  }

  // ── 姓名 + 简介 + 数据统计 ────────────────────────────────────────────────
  FWidget _buildStats() {
    return Container(
      color: '#FFFFFF',
      padding: const EdgeInsets.only(left: 16, right: 16, top: 56, bottom: 16),
      child: Column(
        crossAxisAlignment: 'start',
        spacing: 4,
        children: [
          Text('张小明', fontSize: 20, fontWeight: 'bold', color: '#1A1A1A'),
          Text('@zhangxiaoming', fontSize: 13, color: '#999999'),
          SizedBox(height: 6),
          Text(
            'Flutter 开发者 · 热爱技术与生活 · FuickJS 贡献者',
            fontSize: 14,
            color: '#555555',
          ),
          SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('动态', '128'),
              SizedBox(width: 24),
              _buildStatItem('关注', '326'),
              SizedBox(width: 24),
              _buildStatItem('粉丝', '2.1万'),
            ],
          ),
        ],
      ),
    );
  }

  FWidget _buildStatItem(String label, String value) {
    return Row(
      children: [
        Text(value, fontSize: 16, fontWeight: 'bold', color: '#1A1A1A'),
        SizedBox(width: 4),
        Text(label, fontSize: 13, color: '#999999'),
      ],
    );
  }

  // ── Tab 栏 ────────────────────────────────────────────────────────────────
  FWidget _buildTabs() {
    return Container(
      color: '#FFFFFF',
      child: Column(
        children: [
          Divider(height: 1, thickness: 1, color: '#F0F0F0'),
          Row(
            children: List.generate(_tabs.length, (i) => _buildTabItem(i)),
          ),
        ],
      ),
    );
  }

  FWidget _buildTabItem(int index) {
    final active = _tab == index;
    return Expanded(
      child: Container(
        height: 44,
        alignment: 'center',
        onTap: () => setState(() => _tab = index),
        child: Column(
          mainAxisAlignment: 'center',
          spacing: 2,
          children: [
            Text(
              _tabs[index],
              fontSize: 15,
              color: active ? '#007AFF' : '#666666',
              fontWeight: active ? 'w600' : 'normal',
            ),
            Container(
              width: 20,
              height: 2,
              decoration: BoxDecoration(
                color: active ? '#007AFF' : 'transparent',
                borderRadius: const BorderRadius.all(1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 内容 ──────────────────────────────────────────────────────────────
  FWidget _buildTabContent() {
    switch (_tab) {
      case 0:
        return _buildPosts();
      case 1:
        return _buildCollections();
      default:
        return _buildFollowing();
    }
  }

  // 动态列表
  FWidget _buildPosts() {
    return Column(
      children: _posts.map(_buildPostCard).toList(),
    );
  }

  FWidget _buildPostCard(Map post) {
    return Container(
      color: '#FFFFFF',
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: 'start',
        spacing: 10,
        children: [
          Row(
            children: [
              Image(
                src: post['avatar'] as String,
                width: 40,
                height: 40,
                fit: 'cover',
                borderRadius: 20,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: 'start',
                  spacing: 2,
                  children: [
                    Text(post['name'] as String,
                        fontSize: 14, fontWeight: 'w600', color: '#1A1A1A'),
                    Text(post['time'] as String,
                        fontSize: 12, color: '#999999'),
                  ],
                ),
              ),
            ],
          ),
          Text(post['content'] as String, fontSize: 15, color: '#333333'),
          Row(
            children: [
              _buildActionButton(0xe87d, '${post['likes']}', '#FF6B6B'),
              SizedBox(width: 20),
              _buildActionButton(0xe0b9, '${post['comments']}', '#666666'),
              SizedBox(width: 20),
              _buildActionButton(0xe80d, '分享', '#666666'),
            ],
          ),
          Divider(height: 1, thickness: 1, color: '#F5F5F5'),
        ],
      ),
    );
  }

  FWidget _buildActionButton(int iconCode, String label, String color) {
    return Row(
      children: [
        Icon(codePoint: iconCode, size: 18, color: color),
        SizedBox(width: 4),
        Text(label, fontSize: 13, color: color),
      ],
    );
  }

  // 收藏列表
  FWidget _buildCollections() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        spacing: 12,
        children: _collections.map(_buildCollectionCard).toList(),
      ),
    );
  }

  FWidget _buildCollectionCard(Map item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: item['color'] as String,
        borderRadius: const BorderRadius.all(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: 'start',
              spacing: 6,
              children: [
                Text(item['title'] as String,
                    fontSize: 15, fontWeight: 'w500', color: '#1A1A1A'),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: '#FFFFFF',
                    borderRadius: const BorderRadius.all(10),
                  ),
                  child: Text(item['tag'] as String,
                      fontSize: 11, color: '#666666'),
                ),
              ],
            ),
          ),
          Icon(codePoint: 0xe5c8, size: 20, color: '#CCCCCC'),
        ],
      ),
    );
  }

  // 关注列表（占位）
  FWidget _buildFollowing() {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: 'center',
      child: Column(
        mainAxisAlignment: 'center',
        spacing: 12,
        children: [
          Opacity(
            opacity: 0.3,
            child: Icon(codePoint: 0xe7fb, size: 64, color: '#999999'),
          ),
          Text('暂无关注', fontSize: 15, color: '#999999'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Counter Page（保留原来的简单示例）
// ---------------------------------------------------------------------------

class CounterPage extends StatefulWidget {
  final int initial;
  const CounterPage({this.initial = 0});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  late int count;

  @override
  void initState() {
    count = widget.initial;
  }

  @override
  FWidget build() {
    return Column(
      padding: const EdgeInsets.all(16),
      mainAxisAlignment: 'center',
      crossAxisAlignment: 'center',
      spacing: 12,
      children: [
        Text('Count: $count',
            fontSize: 28, fontWeight: 'bold', color: '#333333'),
        Container(
          width: 180,
          height: 48,
          alignment: 'center',
          decoration: BoxDecoration(
              color: '#007AFF', borderRadius: const BorderRadius.all(8)),
          onTap: () => setState(() => count++),
          child: Text('Increment', color: '#FFFFFF', fontSize: 16),
        ),
        Container(
          width: 180,
          height: 48,
          alignment: 'center',
          decoration: BoxDecoration(
              color: '#FF3B30', borderRadius: const BorderRadius.all(8)),
          onTap: () => setState(() => count = 0),
          child: Text('Reset', color: '#FFFFFF', fontSize: 16),
        ),
        Container(
          width: 180,
          height: 48,
          alignment: 'center',
          decoration: BoxDecoration(
              color: '#34C759', borderRadius: const BorderRadius.all(8)),
          onTap: () {
            callNativeAsync('Dialog.showModal', {
              'title': 'Dart Demo',
              'content': 'Called from Dart via dartCallNativeAsync!',
              'confirmText': 'OK',
              'showCancel': false,
            });
          },
          child: Text('Show Dialog', color: '#FFFFFF', fontSize: 16),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void main() {
  bindGlobals();

  Router.register('/', (_) => const ProfilePage());
  Router.register('/counter', (params) {
    final initial = (params as Map?)?['initial'] ?? 0;
    return CounterPage(
        initial:
            initial is int ? initial : int.tryParse('$initial') ?? 0);
  });
}
