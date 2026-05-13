# 安定性を考え Ubuntu 22.04 を選択（GCC 11との相性も良い）
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. 必要なツールのみをインストール（libfftw3-devは削除）
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc-11 \
    g++-11 \
    cmake \
    git \
    wget \
    ca-certificates \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# 2. 環境変数の設定（nvccパスの安定化とコンパイラ明示）
ENV CC=/usr/bin/gcc-11
ENV CXX=/usr/bin/g++-11
ENV CUDA_PATH=/usr/local/cuda
ENV PATH=${CUDA_PATH}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_PATH}/lib64:${LD_LIBRARY_PATH}

WORKDIR /opt

# 3. ソースコードの取得
RUN git clone https://gitlab.mpcdf.mpg.de/grubmueller/fmm.git && \
    cd fmm && \
    git checkout constant_ph_stable

# 4. ビルド（ディレクトリ作成漏れを防ぐため、一連の流れで実行）
WORKDIR /opt/fmm
RUN mkdir -p build && cd build && \
    cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DGMX_BUILD_OWN_FFTW=ON \
    -DGMX_GPU=CUDA \
    -DGMX_SIMD=AUTO \
    -DGMX_WITH_FMM=ON \
    -DGMX_CONSTANTPH=ON \
    -DGMX_MPI=OFF \
    -DCMAKE_C_COMPILER=/usr/bin/gcc-11 \
    -DCMAKE_CXX_COMPILER=/usr/bin/g++-11 \
    -DCMAKE_CUDA_COMPILER=${CUDA_PATH}/bin/nvcc \
    -DCUDA_NVCC_FLAGS="-Xcompiler;-fPIC" \
    # ここでGPUアーキテクチャを指定（例: Ampere=80, Hopper=90など）
    # 分からない場合は指定せずGROMACSの自動検出に任せるのも手ですが、
    # 特定のスパコン用ならその世代（Compute Capability）を明記するとより安定します
    -DGMX_CUDA_TARGET_SM=90 \ 
    .. && \
    make -j$(nproc) gmx

# 5. 実行環境の設定
ENV PATH=/opt/fmm/build/bin:$PATH

# 全ユーザーに対してGMXRCを自動読み込み
RUN echo "source /opt/fmm/build/bin/GMXRC" >> /etc/bash.bashrc

WORKDIR /simulation
CMD ["/bin/bash"]
