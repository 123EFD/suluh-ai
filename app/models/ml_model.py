import torch
import torch.nn as nn
import joblib

class ResourcePredictorMLP(nn.Module):
    def __init__(self, input_size: int = 8):
        super(ResourcePredictorMLP, self).__init__()
        self.layer1 = nn.Linear(input_size, 32)
        self.dropout = nn.Dropout(0.2)
        self.layer2 = nn.Linear(32, 16)
        self.output = nn.Linear(16, 1)

    def forward(self, x):
        x = torch.relu(self.layer1(x))
        x = self.dropout(x)
        x = torch.relu(self.layer2(x))
        x = self.output(x)
        return x

_model = None
_scaler = None

def get_ml_components():
    """Lazy-loads and caches the PyTorch model and student profile StandardScaler."""
    global _model, _scaler
    if _model is None or _scaler is None:
        try:
            m = ResourcePredictorMLP()
            m.load_state_dict(torch.load('resource_predictor.pth', map_location=torch.device('cpu'), weights_only=True))
            m.eval()
            _model = m
            _scaler = joblib.load('student_scaler.pkl')
            print("AI Engine Ready!")
        except Exception as e:
            print(f"Startup Error loading ML model/scaler: {e}")
    return _model, _scaler
