import os
import json
from collections import defaultdict
import matplotlib.pyplot as plt

result_file = 'result.jtl'
output_file = 'detailed_benchmark_report.html'

errors = []
response_times = []
response_codes = []

with open(result_file, 'r') as f:
    data = json.loads(line)
    if data.get('success') == 'false':
        errors.append({
            'time': data.get('timeStamp'),
            'responseTime': data.get('elapsed'),
            'responseCode': data.get('responseCode'),
            'url': data.get('URL'),
            'shortCode': data.get('label', '').replace('/api/short-link/', '').replace(' ', '')
        })
        response_times.append(data.get('elapsed'))
        response_codes.append(data.get('responseCode'))
    except:
        continue

if errors:
    print("\n=== 错误详情 ===")
    for e in errors:
        print(f"时间: {e['time']}")
        print(f"响应时间: {e['responseTime']}ms")
        print(f"响应码: {e['responseCode']}")
        print(f"URL: {e['url']}")
        print(f"短码: {e['shortCode']}")
else:
else:
    print(f"\n共 {len(response_times)} 个成功请求")
    print(f"平均响应时间: {sum(response_times)/len(response_times):.2f}ms")
    print(f"最小响应时间: {min(response_times)}ms")
    print(f"最大响应时间: {max(response_times)}ms")
    
    sorted_times = sorted(response_times)
    print(f"P50: {sorted_times[int(len(sorted_times)*0.5)],}ms")
    print(f"P90: {sorted_times[int(len(sorted_times)*0.9)],}ms")
    print(f"P95: {sorted_times[int(len(sorted_times)*0.95)],}ms")
    print(f"P99: {sorted_times[int(len(sorted_times)*0.99)],}ms")
    
    plt.figure(figsize=(12, 8))
    plt.subplot(1, 1)
    ax = plt.subplot(1, 1)
    ax.set_title('响应时间分布')
    ax.set_xlabel('响应时间
    ax.set_ylabel('请求数')
    
    bars = ['0-1ms', '1-2ms', '2-3ms', '3-5ms', '5-10ms', '10-15ms', '15-20ms']
    ax.bar(bars, color='green')
    
    plt.subplot(1, 1, )
    ax.set_xlabel('响应时间
    ax.set_ylabel('请求数')
    
    bars = ['0-1ms', '1-2ms', '2-3ms', '3-5ms', '5-10ms', '10-15ms', '15-20ms']
    ax.bar(bars, color='blue')
    
    plt.subplot(1, 1, )
    ax.set_xlabel('响应时间
    ax.set_ylabel('请求数')
    
    bars = ['0-1ms', '1-2ms', '2-3ms', '3-5ms', '5-10ms', '10-15ms', '15-20ms']
    ax.bar(bars, color='red')
    
    plt.tight_layout()
    
    plt.savefig(output_file)
    print(f"\n详细报告已生成: {output_file}")
    print(f"总请求数: {len([l for l in open(result_file, 'r') if json.loads(l).get('success')])}")
    print(f"成功: {len([l for l in open(result_file, 'r') if json.loads(l).get('success')])}")
    print(f"失败: {len([l for l in open(result_file, 'r') if not json.loads(l).get('success')])}")
else:
    print(f"详细报告已保存到: {output_file}")
    print(f"打开报告: {output_file}")

if __name__ == "__main__":
    main()
