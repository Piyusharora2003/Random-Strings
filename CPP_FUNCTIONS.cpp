// PRINT 1D MATRIX
void  _print(vector<int> &prices) {
    for (int i: prices) {
        cout << i  << " ";
    }
    cout << "\n";
}

// PRINT 2D MATRIX
void _print(vector<vector<int>>& matrix) {
    for (const auto &row : matrix) {
        for (const auto &val : row) {
            cout << val << " ";
        }
        cout << '\n';
    }
}

