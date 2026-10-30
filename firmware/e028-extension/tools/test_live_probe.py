import importlib.util
import tempfile
import unittest
import subprocess
import os
from pathlib import Path


class LiveProbeTest(unittest.TestCase):
    def test_decoder_rejects_incomplete_records_and_preserves_signed_bend(self):
        from run_live_probe import decode
        self.assertIsNone(decode('Z1234'))
        self.assertIsNone(decode('Z0000000000000000'))
        row=decode(' ZE0AB01230456A50F\n')
        self.assertTrue(row['armed'])
        self.assertTrue(row['adc_valid'])
        self.assertFalse(row['remote_active'])
        self.assertEqual((row['axis_x'],row['axis_y'],row['optical_raw']), (0x123,0x456,0xA5))
        row=decode('ZE20102A0003FFF03')
        self.assertEqual(row['bend'],-1)
        self.assertTrue(row['brightness_owned'] and row['bend_owned'])

    def test_real_inputs_and_control_logic_are_preserved(self):
        path = Path(__file__).with_name('generate_live_probe.py')
        spec = importlib.util.spec_from_file_location('live_probe', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        root = path.parents[1]
        original = (root / 'src/instrument_core.v').read_text(encoding='utf-8')
        with tempfile.TemporaryDirectory() as directory:
            module.generate(Path(directory))
            core = (Path(directory) / 'instrument_core_live_probe.v').read_text(encoding='utf-8')
            top = (Path(directory) / 'live_probe_top.v').read_text(encoding='utf-8')
        before = original.split('    uart_status monitor(')[0]
        self.assertEqual(core.split('    // Live observer only')[0], before.replace('module instrument_core #', 'module instrument_core_live_probe #', 1))
        expected = (root / 'src/instrument_ap_top.v').read_text(encoding='utf-8')
        expected = expected.replace('module instrument_ap_top', 'module live_probe_top').replace('    assign UART_TX=ESP_RX;', '').replace('    instrument_core #', '    instrument_core_live_probe #').replace('.UART_TX(status_tx_unused)', '.UART_TX(UART_TX)')
        self.assertEqual(top, expected)
        self.assertIn('clk, reset_n', core)
        self.assertNotIn('integration_sequence', core)

    def test_every_snapshot_retains_its_record_identifier(self):
        path = Path(__file__).with_name('generate_live_probe.py')
        spec = importlib.util.spec_from_file_location('live_probe', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        root = path.parents[1]
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory)
            module.generate(destination)
            bench = destination / 'tb_live.sv'
            bench.write_text('''module tb_live;
reg clk=0; always #5 clk=~clk;
live_probe_top dut(.clk(clk),.btn_n(4'hf),.JOY_SW_N(1'b1),.ESP_RX(1'b1),.K230_RX(1'b1));
integer i;
initial begin
#20;
force dut.core.observer_time=26'h3800000;
#1;
for(i=0;i<8;i=i+1)begin
 force dut.core.observer_time=i<<23;
 #1;
 if(dut.core.observer_status[63:56] !== (8'he0+i)) $fatal(1,"record identifier truncated at %0d",i);
end
$display("PASS live observer snapshot identifiers");$finish;
end endmodule
''', encoding='utf-8')
            executable = destination / 'live.vvp'
            binaries = Path('E:/gaoyun/tools/iverilog/ucrt64/bin')
            command = [str(binaries / 'iverilog.exe'), '-g2012', '-s', 'tb_live', '-o', str(executable)]
            command += [str(p) for p in (root / 'src').glob('*.v')]
            command += [str(destination / name) for name in ['instrument_core_live_probe.v', 'live_probe_top.v']]
            command += [str(bench)]
            environment = dict(os.environ)
            environment['PATH'] = 'E:/gaoyun/tools/openfpgaloader/ucrt64/bin;' + str(binaries) + ';' + environment.get('PATH', '')
            result = subprocess.run(command, capture_output=True, text=True, timeout=30, env=environment)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            result = subprocess.run([str(binaries / 'vvp.exe'), str(executable)], capture_output=True, text=True, timeout=10, env=environment)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('PASS', result.stdout)


if __name__ == '__main__':
    unittest.main()
