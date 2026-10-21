# 手势用途、丢手处理V2与开源模型核查

## 赛题定位

按仓库competition-audit-20261018、fpga-review-brief-20261020：光键负责触发/音高，摇杆X/Y已有弯音/亮度。捏合开合优先作为连续表达音量候选，或改映射已有硬件效果的湿声比例；一次选一种明确映射。手部高度可作为未来另一连续控制，但不把多个相关坐标自动计为多个独立演奏维度。切音色/菜单属于离散控制，不直接替代第三独立表情维度。完整串口、FPGA映射、丢失回退与实奏后才能计完成。

K230只负责识别/参数，不承担核心音频。FPGA负责最终限幅、平滑和音频处理。当前尚无K230串口接入，不能宣称≤10ms或第三维已验收；官方模型/例程复用如实注明。

## V2的边界

V1一帧无效即清空并重新等待3帧，可能放大偶发检测失败的操作感。官方run还过滤靠边的小框。这些是已读代码证据，不是已证明用户丢手的唯一根因。

`k230/pinch_preview_v2.py`单文件保留V1作回退。官方检测与关键点预处理、anchors、模型不变；替换组合run的选框逻辑，去掉旧边缘宽度规则，但保留边界与最小框24×36要求。检测底线0.18，取得控制权需>=0.30连续3帧，已锁定手的较弱候选仅允许附近关联，至少0.18；两个强候选仍MULTI HAND。掌宽门槛16像素。降低阈值有误检风险，不能称模型召回率已提高。

短暂缺失最多200ms显示HOLD和旧百分比，valid=0；没有新增推理结果，不作新鲜控制值。超时清空，明显换位重新稳定；多手/非法几何立即无效。此策略改善短断续视觉效果，不解决严重遮挡、侧手、快速运动或远距离细节缺失。接FPGA时必须定义fresh与stale/超时回退，不能仅把屏幕百分比持续发为有效量。

新增诊断：raw_boxes（低阈值原始候选数）、box_reject（几何拒绝数）、age_ms（HOLD旧值时长）、raw_peak（原始最高检测置信度）。raw_boxes=0倾向检测阶段漏检；有原始框但无入选手需看置信度/边界；BAD GEOMETRY需检查关键点和距离。多框数不等于实际有多只手。

## 开源候选（2026-10-21 GitHub API即时查询）

| 项目 | Stars | 仓库许可 | 与本板的关系 |
|---|---:|---|---|
| [Ultralytics](https://github.com/ultralytics/ultralytics) | 62713 | AGPL-3.0 | 高热度YOLO框架，有21点手数据/训练文档；不能把普通COCO检测/人体姿态权重当手部21点模型 |
| [MediaPipe](https://github.com/google-ai-edge/mediapipe) | 37358 | Apache-2.0 | 手检测+21点关键点路线成熟，但不是YOLO，未确认现成兼容本固件的kmodel；算子/转换/后处理需适配 |
| [PINTO model zoo](https://github.com/PINTO0309/PINTO_model_zoo) | 4629 | MIT（仓库） | 多格式模型资源候选，每个上游权重/数据许可另核，不能据仓库MIT认定所有权重可自由再分发 |
| [nncase](https://github.com/kendryte/nncase) | 899 | Apache-2.0（仓库） | K230编译转换工具，不是手模型；K230后端并非全部可从开放源码编译 |
| [K230 CanMV](https://github.com/kendryte/k230_canmv) | 109 | API未识别统一许可 | 平台适配最直接，优先现有亚博模型与配套后处理 |

精确hand-keypoints搜索另找到[YOLO11n-pose-hands](https://github.com/chrismuntean/YOLO11n-pose-hands)，99 stars，API未识别许可；因此未下载/上传其权重，也不称高star且可直接适配亚博。Star数是仓库热度，不是模型精度证据。

[Ultralytics手数据文档](https://docs.ultralytics.com/datasets/pose/hand-keypoints/)描述26768张图、21关键点及训练流程；是数据与训练方案，不等于提供即插即用K230权重。换模型需固定具体权重、许可、输入/归一化、输出关键点索引、ONNX/TFLite算子支持、代表性量化数据，匹配nncase编译器/固件运行时，再对比板上准确率与耗时。现有sys.version不是nncase版本。当前未找到“高star、许可明确、与此亚博固件匹配且已板测”的替代kmodel，所以不为追star盲换模型。

## 验收

固定光照/背景/距离，各做张开/捏合、静止、前后移动、靠边、侧转和移走，每段记录fresh帧占比、最长失效、误检/多框情况及loop_ms分布；比较同场景V1/V2。HOLD帧不能计作识别成功。当前不宣称丢手已解决。
