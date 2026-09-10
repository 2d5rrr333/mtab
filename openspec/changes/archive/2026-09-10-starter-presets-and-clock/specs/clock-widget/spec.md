# clock-widget Delta

## MODIFIED Requirements

### Requirement: 公历时间显示
页面必须实时显示当前公历时间（时、分），并与浏览器本地时间一致；显示必须随时间推进自动更新，无需用户刷新页面。

#### Scenario: 页面加载显示当前时间
- **WHEN** 用户打开导航页
- **THEN** 页面显示当前公历时间（时:分），与浏览器本地时间一致

#### Scenario: 时间自动更新
- **WHEN** 页面保持打开且本地时间推进
- **THEN** 显示的时间随之自动更新
